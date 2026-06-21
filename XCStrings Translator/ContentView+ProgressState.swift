//
//  ContentView+ProgressState.swift
//  XCStrings Translator
//
//  Created by Wesley de Groot on 21/06/2026.
//

import Foundation

extension ContentView {
    var isTranslating: Bool {
        translationConfiguration != nil
    }

    var availableTargetLanguages: [Locale.Language] {
        TranslationTargetsResolver.targets(
            for: destinationSelection,
            sourceLanguage: sourceLanguage,
            supportedLanguages: targetLanguageOptions
        )
    }

    var canTranslate: Bool {
        !isTranslating &&
        sourceLanguage != nil &&
        !languageParser.stringsToTranslate.isEmpty &&
        !availableTargetLanguages.isEmpty
    }

    var canSave: Bool {
        !isTranslating &&
        !languageParser.stringsToTranslate.isEmpty &&
        (didFinishTranslation || completedTranslatedUnitsForRun > 0)
    }

    /// Completed work that is already written into `LanguageParser.languageDictionary`.
    ///
    /// `translatedStrings` only stores rows for the active target language. Completed
    /// languages are counted separately so cancellation still shows accurate progress
    /// and allows saving partial results.
    var completedTranslatedUnitsForRun: Int {
        completedUnitsBeforeCurrentTarget + translatedStrings.count
    }

    var totalTranslationUnits: Int {
        if totalTranslationUnitsForRun > 0 {
            return totalTranslationUnitsForRun
        }

        return languageParser.stringsToTranslate.count * max(availableTargetLanguages.count, 1)
    }

    var completedTranslationUnits: Int {
        if isTranslating {
            return completedTranslatedUnitsForRun
        }

        if didFinishTranslation {
            return totalTranslationUnits
        }

        return completedTranslatedUnitsForRun
    }

    var progressValue: Double {
        guard totalTranslationUnits > 0 else {
            return 0
        }

        return min(Double(completedTranslationUnits) / Double(totalTranslationUnits), 1)
    }

    var selectedTargetCount: Int {
        if totalTargetLanguages > 0 {
            return totalTargetLanguages
        }

        return availableTargetLanguages.count
    }

    var progressStringsToTranslate: Int {
        if isTranslating || currentTargetTranslationUnits > 0 {
            return currentTargetTranslationUnits
        }

        return languageParser.stringsToTranslate.count
    }

    var elapsedTranslationTime: TimeInterval {
        guard let translationStartedAt else {
            return 0
        }

        return max((translationEndedAt ?? timerDate).timeIntervalSince(translationStartedAt), 0)
    }

    var elapsedTranslationText: String {
        guard translationStartedAt != nil else {
            return "Not started"
        }

        return formattedDuration(elapsedTranslationTime)
    }

    var estimatedTimeRemainingText: String {
        guard translationStartedAt != nil else {
            return "Not started"
        }

        guard isTranslating else {
            return didFinishTranslation ? "Done" : "Stopped"
        }

        guard completedTranslationUnits > 0,
              totalTranslationUnits > completedTranslationUnits,
              elapsedTranslationTime > 0 else {
            return "Calculating"
        }

        let unitsPerSecond = Double(completedTranslationUnits) / elapsedTranslationTime

        guard unitsPerSecond > 0 else {
            return "Calculating"
        }

        let remainingUnits = totalTranslationUnits - completedTranslationUnits
        return formattedDuration(Double(remainingUnits) / unitsPerSecond)
    }
}
