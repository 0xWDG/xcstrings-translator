//
//  ContentView+Translation.swift
//  XCStrings Translator
//
//  Created by Wesley de Groot on 21/06/2026.
//

import Foundation
import Translation
import SwiftUI

extension ContentView {
    @MainActor
    func configureInitialLanguages() async {
        let languages = await languageAvailability.supportedLanguages
        let defaultSourceLanguage = languages.first(where: { $0.languageCode == "en" })

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

    func languageName(for language: Locale.Language) -> String? {
        languageList.language(for: language)?.name
    }

    @MainActor
    func openStringCatalog(_ url: URL) {
        resetTranslationState()
        languageParser.load(file: url)

        // The catalog source language is stored as a string identifier. Match by
        // language code so region-specific catalog values still select the available
        // system source language.
        sourceLanguage = supportedLanguages.first(where: {
            $0.languageCode == Locale.Language(
                identifier: languageParser.sourceLanguage
            ).languageCode
        })
    }

    @MainActor
    func updateDockProgress() {
        DockProgressController.shared.update(
            progress: progressValue,
            isVisible: isTranslating
        )
    }

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

    @MainActor
    func setDestinationSelectionIfNeeded(_ selection: TranslationTargetSelection) {
        guard destinationSelection != selection else {
            return
        }

        destinationSelection = selection
    }

    func languageIdentifiers(for languages: [Locale.Language]) -> [String] {
        languages.map {
            TranslationTargetsResolver.languageIdentifier(for: $0) ??
                $0.maximalIdentifier
        }
    }

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

    @MainActor
    func askToSetDefaultStringCatalogAppIfNeeded() {
        guard DefaultStringCatalogAppManager.shouldPromptAfterTranslation else {
            return
        }

        defaultAppPromptPresented = true
    }

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
