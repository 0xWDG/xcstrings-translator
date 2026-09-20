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
}

/// Planning and execution for Translation framework sessions.
///
/// A run may include multiple target languages. Each target gets its own
/// `TranslationSession.Configuration` because the framework binds a session to one
/// source/target pair.
extension ContentView {
    /// Starts a translation run if a valid plan can be built.
    ///
    /// - Parameter overwritingExistingTranslations: When `true`, existing target
    ///   values are translated again instead of being skipped.
    ///
    /// Side Effects:
    /// Mutates run state on the main actor and eventually triggers `.translationTask`.
    func translate(overwritingExistingTranslations: Bool = false) async {
        guard let runPlan = await translationRunPlan(
            overwritingExistingTranslations: overwritingExistingTranslations
        ) else {
            return
        }

        await MainActor.run {
            startTranslationRun(runPlan)
        }
    }

    /// Builds the exact set of target languages and units for a run.
    ///
    /// - Parameter overwritingExistingTranslations: Whether to ignore the user's
    ///   "skip already translated" setting for this run.
    /// - Returns: A plan when at least one compatible target has pending work.
    ///
    /// Possible Errors:
    /// Translation availability checks do not throw; failure to find compatible work
    /// is reported through `status` and a `nil` return.
    ///
    /// Performance:
    /// This performs availability checks before creating sessions so the run avoids
    /// starting targets that the framework would reject.
    func translationRunPlan(
        overwritingExistingTranslations: Bool
    ) async -> TranslationRunPlan? {
        // Re-check pair availability immediately before translating. Supported system
        // languages can include pairs the Translation framework still cannot serve.
        let targetLanguages = await compatibleTargetLanguages(from: availableTargetLanguages)
        let skippingTranslated = await MainActor.run {
            !overwritingExistingTranslations && languageParser.skipAlreadyTranslated
        }

        guard !targetLanguages.isEmpty else {
            await MainActor.run {
                status = "No compatible translation languages available"
            }
            return nil
        }

        // With "skip already translated" enabled, some selected targets may have no
        // remaining strings. Removing them up front keeps progress totals accurate.
        let targetLanguagesWithWork = await MainActor.run {
            targetLanguages.filter { targetLanguage in
                !stringsToTranslate(
                    for: targetLanguage,
                    skippingTranslated: skippingTranslated
                ).isEmpty
            }
        }

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
                skippingTranslated: skippingTranslated
            )
        }

        guard totalTranslationUnits > 0 else {
            await MainActor.run {
                resetTranslationState()
                status = "No untranslated strings available"
            }
            return nil
        }

        return TranslationRunPlan(
            targetLanguages: targetLanguagesWithWork,
            totalTranslationUnits: totalTranslationUnits,
            skippingTranslated: skippingTranslated
        )
    }

    /// Applies a run plan to view state and starts the first target language.
    ///
    /// - Parameter runPlan: Plan returned by `translationRunPlan(overwritingExistingTranslations:)`.
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
    func translate(using session: TranslationSession) async {
        let stringsToTranslate = await MainActor.run(resultType: [String].self) {
            self.stringsToTranslate(
                for: activeTargetLanguage,
                skippingTranslated: skipAlreadyTranslatedForCurrentRun
            )
        }
        let targetLanguage = await MainActor.run { activeTargetLanguage }

        guard targetLanguage != nil else {
            return
        }

        do {
            for string in stringsToTranslate {
                // Cancellation is cooperative: check before starting each request and
                // again before writing the response back into the catalog.
                if await MainActor.run(resultType: Bool.self, body: {
                    cancelTranslationRequested
                }) {
                    return
                }

                await MainActor.run {
                    currentTranslation = string
                }

                let response = try await session.translate(string)

                await MainActor.run {
                    guard !cancelTranslationRequested else {
                        return
                    }

                    translatedStrings[response.sourceText] = response.targetText
                    languageParser.add(translation: response)
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
