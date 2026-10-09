//
//  ContentView+TranslationRun.swift
//  XCStrings Translator
//
//  Created by Wesley de Groot on 21/06/2026.
//

import SwiftUI
import Translation

/// Immutable plan for one translation run.
///
/// The plan is computed immediately before translation starts so progress totals use
/// the latest source strings, target language availability, and skip setting.
struct TranslationRunPlan {
    /// Target languages that have work to perform.
    let targetLanguages: [Locale.Language]
    /// Total source-string/target-language units in this run.
    let totalTranslationUnits: Int
    /// Whether already translated strings were excluded when the plan was built.
    let skippingTranslated: Bool
    /// Whether target variants collapse to their main language catalog key.
    let mainLanguagesOnly: Bool
}

/// Planning and execution for Translation framework sessions.
///
/// A run may include multiple target languages. Each target gets its own
/// `TranslationSession.Configuration` because the framework binds a session to one
/// source/target pair.
extension ContentView {
    /// Starts a translation run if a valid plan can be built.
    ///
    /// - Parameters:
    ///   - overwritingExistingTranslations: When `true`, existing target values are
    ///     translated again instead of being skipped.
    ///   - onlyUpdatingExistingLanguages: When `true`, the run excludes targets not
    ///     already represented in the catalog.
    ///   - includingAllLanguageVariants: When `true`, the run expands the selected
    ///     target to every compatible regional and script variant.
    ///
    /// Side Effects:
    /// Mutates run state on the main actor and eventually triggers `.translationTask`.
    func translate(
        overwritingExistingTranslations: Bool = false,
        onlyUpdatingExistingLanguages: Bool = false,
        includingAllLanguageVariants: Bool = false
    ) async {
        guard let runPlan = await translationRunPlan(
            overwritingExistingTranslations: overwritingExistingTranslations,
            onlyUpdatingExistingLanguages: onlyUpdatingExistingLanguages,
            includingAllLanguageVariants: includingAllLanguageVariants
        ) else {
            return
        }

        await MainActor.run {
            startTranslationRun(runPlan)
        }
    }

    /// Builds the exact set of target languages and units for a run.
    ///
    /// - Parameters:
    ///   - overwritingExistingTranslations: Whether to ignore the user's "skip
    ///     already translated" setting for this run.
    ///   - onlyUpdatingExistingLanguages: Whether to exclude targets not already
    ///     represented in the catalog.
    ///   - includingAllLanguageVariants: Whether to expand the selection to every
    ///     compatible regional and script variant.
    /// - Returns: A plan when at least one compatible target has pending work and,
    ///   for existing-language-only runs, is already represented in the catalog.
    ///
    /// Possible Errors:
    /// Translation availability checks do not throw; failure to find compatible work
    /// is reported through `status` and a `nil` return.
    ///
    /// Performance:
    /// This performs availability checks before creating sessions so the run avoids
    /// starting targets that the framework would reject.
    func translationRunPlan(
        overwritingExistingTranslations: Bool,
        onlyUpdatingExistingLanguages: Bool,
        includingAllLanguageVariants: Bool
    ) async -> TranslationRunPlan? {
        // Re-check pair availability immediately before translating. Supported system
        // languages can include pairs the Translation framework still cannot serve.
        let mainLanguagesOnly = !includingAllLanguageVariants && languageParser.mainLanguagesOnly
        let selectedTargetLanguages = await targetLanguagesForRun(
            includingAllLanguageVariants: includingAllLanguageVariants
        )
        let targetLanguages = await compatibleTargetLanguages(from: selectedTargetLanguages)
        let eligibleTargetLanguages = onlyUpdatingExistingLanguages
            ? targetLanguagesEligibleForUpdate(
                from: targetLanguages,
                mainLanguagesOnly: mainLanguagesOnly
            )
            : targetLanguages
        let skippingTranslated = await MainActor.run {
            !overwritingExistingTranslations && languageParser.skipAlreadyTranslated
        }

        guard !eligibleTargetLanguages.isEmpty else {
            await MainActor.run {
                status = onlyUpdatingExistingLanguages
                    ? "No existing target languages available"
                    : "No compatible translation languages available"
            }
            return nil
        }

        // With "skip already translated" enabled, some selected targets may have no
        // remaining strings. Removing them up front keeps progress totals accurate.
        let targetLanguagesWithWork = targetLanguagesWithPendingWork(
            from: eligibleTargetLanguages,
            skippingTranslated: skippingTranslated,
            mainLanguagesOnly: mainLanguagesOnly
        )

        guard !targetLanguagesWithWork.isEmpty else {
            await MainActor.run {
                resetTranslationState()
                status = "No untranslated strings available"
            }
            return nil
        }

        let totalTranslationUnits = await MainActor.run(resultType: Int.self) {
            self.totalTranslationUnits(
                for: targetLanguagesWithWork,
                skippingTranslated: skippingTranslated,
                mainLanguagesOnly: mainLanguagesOnly
            )
        }

        return TranslationRunPlan(
            targetLanguages: targetLanguagesWithWork,
            totalTranslationUnits: totalTranslationUnits,
            skippingTranslated: skippingTranslated,
            mainLanguagesOnly: mainLanguagesOnly
        )
    }

    /// Resolves the current picker selection into targets for a translation run.
    ///
    /// - Parameter includingAllLanguageVariants: Whether a run should include every
    ///   compatible regional and script variant of the selected target.
    /// - Returns: Targets appropriate for the requested run granularity.
    func targetLanguagesForRun(
        includingAllLanguageVariants: Bool
    ) async -> [Locale.Language] {
        guard includingAllLanguageVariants else {
            return availableTargetLanguages
        }

        let allLanguageVariants = await availableSystemTargetLanguages(
            mainLanguagesOnly: false
        )

        guard case let .language(selectedLanguage) = destinationSelection else {
            return allLanguageVariants
        }

        return allLanguageVariants.filter {
            $0.languageCode?.identifier == selectedLanguage.languageCode?.identifier
        }
    }

    /// Filters compatible targets to ones already represented in the catalog.
    ///
    /// - Parameter targetLanguages: Translation-framework-compatible target languages.
    /// - Returns: Only targets whose catalog localization already exists.
    @MainActor
    func targetLanguagesEligibleForUpdate(
        from targetLanguages: [Locale.Language],
        mainLanguagesOnly: Bool
    ) -> [Locale.Language] {
        targetLanguages.filter { targetLanguage in
            languageParser.hasExistingLocalization(
                forLanguage: targetLanguageIdentifier(
                    for: targetLanguage,
                    mainLanguagesOnly: mainLanguagesOnly
                )
            )
        }
    }

    /// Removes targets that have no source strings left to translate.
    ///
    /// - Parameters:
    ///   - targetLanguages: Compatible targets to inspect.
    ///   - skippingTranslated: Whether complete existing values count as complete.
    ///   - mainLanguagesOnly: Whether target variants use their collapsed catalog key.
    /// - Returns: Targets that still have at least one pending source string.
    @MainActor
    func targetLanguagesWithPendingWork(
        from targetLanguages: [Locale.Language],
        skippingTranslated: Bool,
        mainLanguagesOnly: Bool
    ) -> [Locale.Language] {
        targetLanguages.filter { targetLanguage in
            !stringsToTranslate(
                for: targetLanguage,
                skippingTranslated: skippingTranslated,
                mainLanguagesOnly: mainLanguagesOnly
            ).isEmpty
        }
    }

    /// Applies a run plan to view state and starts the first target language.
    ///
    /// - Parameter runPlan: Plan returned by
    ///   `translationRunPlan(overwritingExistingTranslations:onlyUpdatingExistingLanguages:
    ///   includingAllLanguageVariants:)`.
    ///
    /// Side Effects:
    /// Initializes progress counters, timestamps, the pending-language queue, and the
    /// first `TranslationSession.Configuration`.
    @MainActor
    func startTranslationRun(_ runPlan: TranslationRunPlan) {
        // Each target language gets its own TranslationSession. `beginTranslation`
        // sets `translationConfiguration`, which triggers SwiftUI's translationTask.
        cancelTranslationRequested = false
        didFinishTranslation = false
        skipAlreadyTranslatedForCurrentRun = runPlan.skippingTranslated
        mainLanguagesOnlyForCurrentRun = runPlan.mainLanguagesOnly
        completedTargetLanguages = 0
        completedUnitsBeforeCurrentTarget = 0
        totalTranslationUnitsForRun = runPlan.totalTranslationUnits
        totalTargetLanguages = runPlan.targetLanguages.count
        pendingTargetLanguages = Array(runPlan.targetLanguages.dropFirst())
        translationStartedAt = Date()
        translationEndedAt = nil
        timerDate = translationStartedAt ?? Date()

        if let firstTargetLanguage = runPlan.targetLanguages.first {
            beginTranslation(for: firstTargetLanguage)
        }
    }

    /// Executes translations for the active `TranslationSession`.
    ///
    /// - Parameter session: SwiftUI-provided Translation framework session matching
    ///   `translationConfiguration`.
    ///
    /// Possible Errors:
    /// Individual `session.translate(_:)` calls can throw. Non-cancellation errors are
    /// routed to `failTranslation(_:)`; cancellation exits quietly because the UI has
    /// already been updated.
    ///
    /// Side Effects:
    /// Updates the current-row indicator, writes successful responses into
    /// `LanguageParser`, advances progress, and finishes the active target language.
    ///
    /// Thread Safety:
    /// The loop runs asynchronously, but every read/write of SwiftUI state and the
    /// parser is performed through `MainActor.run`.
    func translate(using session: TranslationSession) async { // swiftlint:disable:this function_body_length
        let stringKeysToTranslate = await MainActor.run(resultType: [String].self) {
            self.stringsToTranslate(
                for: activeTargetLanguage,
            skippingTranslated: skipAlreadyTranslatedForCurrentRun,
            mainLanguagesOnly: mainLanguagesOnlyForCurrentRun
            )
        }
        let targetLanguageIdentifier = await MainActor.run {
            targetLanguageIdentifier(
                for: activeTargetLanguage,
                mainLanguagesOnly: mainLanguagesOnlyForCurrentRun
            )
        }

        guard let targetLanguageIdentifier else {
            return
        }

        do {
            for key in stringKeysToTranslate {
                // Cancellation is cooperative: check before starting each request and
                // again before writing the response back into the catalog.
                if await MainActor.run(resultType: Bool.self, body: {
                    cancelTranslationRequested
                }) {
                    return
                }

                await MainActor.run {
                    currentTranslation = key
                }

                let sourceText = await MainActor.run {
                    languageParser.sourceText(for: key)
                }
                let response = try await session.translate(sourceText)

                await MainActor.run {
                    guard !cancelTranslationRequested else {
                        return
                    }

                    translatedStrings[key] = response.targetText
                    languageParser.add(
                        translation: response.targetText,
                        forLanguage: targetLanguageIdentifier,
                        original: key,
                        source: sourceText
                    )
                }
            }

            await MainActor.run {
                finishCurrentTarget()
            }
        } catch {
            if await MainActor.run(resultType: Bool.self, body: {
                cancelTranslationRequested
            }) {
                return
            }

            await MainActor.run {
                failTranslation(error)
            }
        }
    }
}
