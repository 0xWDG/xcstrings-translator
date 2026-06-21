//
//  ContentView+TranslationRun.swift
//  XCStrings Translator
//
//  Created by Wesley de Groot on 21/06/2026.
//

import Translation
import SwiftUI

struct TranslationRunPlan {
    let targetLanguages: [Locale.Language]
    let totalTranslationUnits: Int
    let skippingTranslated: Bool
}

extension ContentView {
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
