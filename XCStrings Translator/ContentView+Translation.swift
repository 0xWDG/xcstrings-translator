//
//  ContentView+Translation.swift
//  XCStrings Translator
//
//  Created by Wesley de Groot on 21/06/2026.
//

import Foundation
import Translation
import SwiftUI

/// User actions and lifecycle transitions for the translation workflow.
///
/// This extension keeps state mutations together: file opening, language refresh,
/// run reset, cancellation, finish/failure handling, and duration formatting. The
/// asynchronous request loop itself lives in `ContentView+TranslationRun`.
extension ContentView {
    /// Loads Translation framework language availability and selects initial defaults.
    ///
    /// Side Effects:
    /// Updates `supportedLanguages`, `sourceLanguage`, `targetLanguageOptions`, and
    /// potentially `destinationSelection`.
    @MainActor
    func configureInitialLanguages() async {
        let languages = await languageAvailability.supportedLanguages
        let defaultSourceLanguage = preferredDefaultSourceLanguage(in: languages)

        // Avoid reassigning equivalent arrays. SwiftUI treats every assignment as a
        // dependency update, and redundant updates can contribute to AttributeGraph
        // cycles when paired with other onChange handlers.
        if languageIdentifiers(for: supportedLanguages) != languageIdentifiers(for: languages) {
            supportedLanguages = languages
        }

        if sourceLanguage != defaultSourceLanguage {
            sourceLanguage = defaultSourceLanguage
        }

        await refreshAvailableTargetLanguages(selectDefaultTarget: true)
    }

    /// Chooses the preferred source language from the system-supported list.
    ///
    /// - Parameter languages: Languages reported by `LanguageAvailability`.
    /// - Returns: `en-US` when available, otherwise the first English language.
    func preferredDefaultSourceLanguage(in languages: [Locale.Language]) -> Locale.Language? {
        languages.first(where: { $0.matchesLanguageIdentifier("en-US") }) ??
            languages.first(where: { $0.languageCode?.identifier == "en" })
    }

    /// Returns a localized display name for a language.
    ///
    /// - Parameter language: Language to display in the UI.
    /// - Returns: Localized language name, or `nil` when Foundation has no display name.
    func languageName(for language: Locale.Language) -> String? {
        language.localizedDisplayName()
    }

    /// Loads a string catalog and aligns the source picker with the catalog language.
    ///
    /// - Parameter url: URL received from the file picker or an Open URL event.
    ///
    /// Side Effects:
    /// Resets the current translation run, mutates `languageParser`, and updates the
    /// selected source language.
    @MainActor
    func openStringCatalog(_ url: URL) {
        resetTranslationState()
        languageParser.load(file: url)

        // The catalog source language is stored as a string identifier. Match by
        // language code so region-specific catalog values still select the available
        // system source language.
        let catalogSourceLanguage = Locale.Language(identifier: languageParser.sourceLanguage)
        let matchingLanguages = supportedLanguages.filter {
            $0.languageCode == catalogSourceLanguage.languageCode
        }

        sourceLanguage = if catalogSourceLanguage.languageCode?.identifier == "en" {
            preferredDefaultSourceLanguage(in: matchingLanguages)
        } else {
            matchingLanguages.first
        }
    }

    /// Updates or clears the Dock tile progress overlay.
    ///
    /// Side Effects:
    /// Mutates AppKit's `NSDockTile` through `DockProgressController`.
    @MainActor
    func updateDockProgress() {
        DockProgressController.shared.update(
            progress: progressValue,
            isVisible: isTranslating
        )
    }

    /// Resolves the persisted default-target setting into a picker selection.
    ///
    /// - Returns: A single matching language or `.allAvailable` when the setting is
    ///   the sentinel value or no longer matches current system language support.
    func defaultDestinationSelection() -> TranslationTargetSelection {
        let identifier = languageParser.defaultTargetLanguageIdentifier

        guard identifier != LanguageParser.allLanguagesDefaultTargetIdentifier else {
            return .allAvailable
        }

        if let language = targetLanguageOptions.first(where: {
            TranslationTargetsResolver.languageIdentifier(for: $0) == identifier ||
            $0.minimalIdentifier == identifier ||
            $0.maximalIdentifier == identifier
        }) {
            return .language(language)
        }

        return .allAvailable
    }

    /// Rebuilds the target-language picker options for the current source language.
    ///
    /// - Parameter selectDefaultTarget: Whether to also apply the persisted default
    ///   target selection after refreshing options.
    ///
    /// Side Effects:
    /// Updates `targetLanguageOptions` and possibly `destinationSelection`.
    @MainActor
    func refreshAvailableTargetLanguages(selectDefaultTarget: Bool) async {
        let availableLanguages = await availableSystemTargetLanguages()

        // Keep this idempotent. Source-language changes and initial setup both call
        // this path, and unnecessary writes cause extra view invalidations.
        if languageIdentifiers(for: targetLanguageOptions) != languageIdentifiers(for: availableLanguages) {
            targetLanguageOptions = availableLanguages
        }

        if selectDefaultTarget {
            setDestinationSelectionIfNeeded(defaultDestinationSelection())
        }
    }

    /// Assigns a destination selection only when it differs from the current value.
    ///
    /// Avoiding redundant writes prevents extra `onChange` resets in the root view.
    @MainActor
    func setDestinationSelectionIfNeeded(_ selection: TranslationTargetSelection) {
        guard destinationSelection != selection else {
            return
        }

        destinationSelection = selection
    }

    /// Converts languages to the identifiers used for equality checks.
    ///
    /// - Parameter languages: Languages to normalize.
    /// - Returns: Catalog identifiers with `maximalIdentifier` as the fallback.
    func languageIdentifiers(for languages: [Locale.Language]) -> [String] {
        languages.map {
            TranslationTargetsResolver.languageIdentifier(for: $0) ??
                $0.maximalIdentifier
        }
    }

    /// Clears all per-run progress and status state without unloading the catalog.
    ///
    /// Side Effects:
    /// Resets translation UI state and snapshots the current skip setting for the next
    /// run.
    @MainActor
    func resetTranslationState() {
        translatedStrings = [:]
        translationConfiguration = nil
        activeTargetLanguage = nil
        pendingTargetLanguages = []
        totalTargetLanguages = 0
        completedTargetLanguages = 0
        totalTranslationUnitsForRun = 0
        completedUnitsBeforeCurrentTarget = 0
        currentTargetTranslationUnits = 0
        skipAlreadyTranslatedForCurrentRun = languageParser.skipAlreadyTranslated
        didFinishTranslation = false
        cancelTranslationRequested = false
        currentTranslation = nil
        translationStartedAt = nil
        translationEndedAt = nil
        timerDate = Date()
        status = "Idle"
    }

    /// Starts translating a single target language.
    ///
    /// - Parameter targetLanguage: Language for the next `TranslationSession`.
    ///
    /// Side Effects:
    /// Updates active-target progress state and sets `translationConfiguration`, which
    /// triggers SwiftUI's `.translationTask` modifier.
    @MainActor
    func beginTranslation(for targetLanguage: Locale.Language) {
        activeTargetLanguage = targetLanguage

        // The visible row map is target-specific. The full catalog remains in
        // LanguageParser and is updated after every successful Translation response.
        translatedStrings = [:]
        currentTranslation = nil
        currentTargetTranslationUnits = stringsToTranslate(
            for: targetLanguage,
            skippingTranslated: skipAlreadyTranslatedForCurrentRun
        ).count
        status = translationStatus(
            for: targetLanguage,
            completedTargets: completedTargetLanguages,
            totalTargets: totalTargetLanguages
        )
        translationConfiguration = TranslationSession.Configuration(
            source: sourceLanguage,
            target: targetLanguage
        )
    }

    /// Builds the status text for the active target language.
    ///
    /// - Parameters:
    ///   - targetLanguage: Language currently being translated.
    ///   - completedTargets: Count of target languages already completed.
    ///   - totalTargets: Total target languages in the run.
    /// - Returns: User-facing progress status.
    func translationStatus(
        for targetLanguage: Locale.Language,
        completedTargets: Int,
        totalTargets: Int
    ) -> String {
        let targetName = languageName(for: targetLanguage) ??
            TranslationTargetsResolver.languageIdentifier(for: targetLanguage) ??
            targetLanguage.maximalIdentifier

        if totalTargets > 1 {
            return "Translating \(targetName) (\(completedTargets + 1)/\(totalTargets))"
        }

        return "Translating \(targetName)"
    }

    /// Requests cancellation of the active translation run.
    ///
    /// Side Effects:
    /// Clears the active session configuration, preserves already inserted parser
    /// results, and updates status so the user can save partial work.
    @MainActor
    func cancelTranslation() {
        let completedUnits = completedTranslatedUnitsForRun

        // Do not clear LanguageParser here. It already contains completed responses,
        // so the user can save partial results after cancellation.
        cancelTranslationRequested = true
        translationConfiguration = nil
        activeTargetLanguage = nil
        pendingTargetLanguages = []
        currentTranslation = nil
        currentTargetTranslationUnits = 0
        translationEndedAt = Date()
        timerDate = translationEndedAt ?? Date()
        didFinishTranslation = false

        if completedUnits > 0 {
            status = "Translation cancelled, partial results can be saved"
        } else {
            status = "Translation cancelled"
        }
    }

    /// Marks the active target language complete and starts the next one if queued.
    ///
    /// Side Effects:
    /// Updates progress counters, optionally saves a checkpoint, advances the pending
    /// language queue, and shows the default-app prompt when the whole run completes.
    @MainActor
    func finishCurrentTarget() {
        guard !cancelTranslationRequested else {
            return
        }

        completedTargetLanguages += 1
        completedUnitsBeforeCurrentTarget += currentTargetTranslationUnits

        // Persist after each completed language before starting the next one. This
        // limits data loss if the app crashes during a later target language.
        guard saveCompletedLanguageCheckpointIfNeeded() else {
            activeTargetLanguage = nil
            translationConfiguration = nil
            currentTranslation = nil
            currentTargetTranslationUnits = 0
            translationEndedAt = Date()
            timerDate = translationEndedAt ?? Date()
            didFinishTranslation = false
            return
        }

        if let nextTargetLanguage = pendingTargetLanguages.first {
            pendingTargetLanguages.removeFirst()
            beginTranslation(for: nextTargetLanguage)
            return
        }

        activeTargetLanguage = nil
        translationConfiguration = nil
        currentTranslation = nil
        currentTargetTranslationUnits = 0
        translationEndedAt = Date()
        timerDate = translationEndedAt ?? Date()
        didFinishTranslation = true

        if totalTargetLanguages > 1 {
            status = "Finished translating \(completedTargetLanguages) languages, idle"
        } else {
            status = "Finished translating, idle"
        }

        askToSetDefaultStringCatalogAppIfNeeded()
    }

    /// Saves an auto-save checkpoint after a target language completes.
    ///
    /// - Returns: `true` when translation may continue, or `false` when saving failed
    ///   and the run should stop before starting another target.
    /// - Throws: This method catches and logs save errors because it is called from UI
    ///   workflow code that reports failures through `status`.
    @MainActor
    func saveCompletedLanguageCheckpointIfNeeded() -> Bool {
        guard languageParser.autoSaveTranslations else {
            return true
        }

        do {
            // Test Mode deliberately exercises the flow without touching the source
            // catalog on disk.
            switch try languageParser.saveToLoadedFile() {
            case .saved:
                logger.debug("Saved completed language checkpoint.")
            case .skippedTesting:
                logger.debug("Skipped completed language checkpoint save in Test Mode.")
            }

            return true
        } catch {
            logger.error("Completed language checkpoint save failed: \(error.localizedDescription, privacy: .public)")
            status = "Language finished, but checkpoint save failed"
            return false
        }
    }

    /// Presents the default-app prompt after a successful run when appropriate.
    @MainActor
    func askToSetDefaultStringCatalogAppIfNeeded() {
        guard DefaultStringCatalogAppManager.shouldPromptAfterTranslation else {
            return
        }

        defaultAppPromptPresented = true
    }

    /// Requests Launch Services registration for `.xcstrings` files.
    ///
    /// Side Effects:
    /// Calls into `DefaultStringCatalogAppManager` and updates the status label with
    /// the result.
    @MainActor
    func setDefaultStringCatalogApp() {
        DefaultStringCatalogAppManager.setAsDefault { result in
            switch result {
            case let .failure(error):
                logger.error(
                    "Setting default app failed: \(error.localizedDescription, privacy: .public)"
                )
                status = "Could not set XCStrings translator as the default app"
            case .success:
                status = "XCStrings translator is now the default app for .xcstrings files"
            }
        }
    }

    /// Handles a Translation framework failure.
    ///
    /// - Parameter error: Error thrown by `TranslationSession`.
    ///
    /// Side Effects:
    /// Logs the error, clears active translation state, preserves completed parser
    /// results, and marks the run as failed in the status label.
    @MainActor
    func failTranslation(_ error: Error) {
        logger.error(
            "Translation failed: \(error.localizedDescription, privacy: .public)"
        )
        translationConfiguration = nil
        activeTargetLanguage = nil
        pendingTargetLanguages = []
        currentTranslation = nil
        currentTargetTranslationUnits = 0
        translationEndedAt = Date()
        timerDate = translationEndedAt ?? Date()
        didFinishTranslation = false
        status = "Translation failed"
    }

    /// Formats a duration for compact progress UI.
    ///
    /// - Parameter duration: Time interval in seconds.
    /// - Returns: `1h 2m`, `2m 3s`, or `3s` depending on magnitude.
    func formattedDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(Int(duration.rounded()), 0)
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }

        return "\(seconds)s"
    }

}
