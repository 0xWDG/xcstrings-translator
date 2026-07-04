//
//  ContentView+ProgressState.swift
//  XCStrings Translator
//
//  Created by Wesley de Groot on 21/06/2026.
//

import Foundation

/// Derived progress and command-availability state for `ContentView`.
///
/// These properties intentionally live outside the main view declaration to keep the
/// SwiftUI body focused on layout. They do not mutate state; they translate the raw
/// workflow fields into values that controls and progress indicators can consume.
extension ContentView {
    /// Whether a Translation framework session is currently active.
    var isTranslating: Bool {
        translationConfiguration != nil
    }

    /// Concrete target languages represented by the current picker selection.
    var availableTargetLanguages: [Locale.Language] {
        TranslationTargetsResolver.targets(
            for: destinationSelection,
            sourceLanguage: sourceLanguage,
            supportedLanguages: targetLanguageOptions
        )
    }

    /// Whether the Translate action has all inputs needed to start a run.
    var canTranslate: Bool {
        !isTranslating &&
        sourceLanguage != nil &&
        !languageParser.stringsToTranslate.isEmpty &&
        !availableTargetLanguages.isEmpty
    }

    /// Whether the current catalog has completed or partial work that can be exported.
    ///
    /// Saving is disabled during active translation because the parser is being
    /// mutated response by response.
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

    /// Total work units shown by the progress bar.
    ///
    /// Before a run is planned, this uses a simple estimate based on current source
    /// strings and selected targets. Once a run starts, the exact planned count is
    /// retained so progress does not jump when translated strings are skipped.
    var totalTranslationUnits: Int {
        if totalTranslationUnitsForRun > 0 {
            return totalTranslationUnitsForRun
        }

        return languageParser.stringsToTranslate.count * max(availableTargetLanguages.count, 1)
    }

    /// Completed work units shown by the progress bar.
    var completedTranslationUnits: Int {
        if isTranslating {
            return completedTranslatedUnitsForRun
        }

        if didFinishTranslation {
            return totalTranslationUnits
        }

        return completedTranslatedUnitsForRun
    }

    /// Fractional progress clamped to SwiftUI `ProgressView`'s expected range.
    var progressValue: Double {
        guard totalTranslationUnits > 0 else {
            return 0
        }

        return min(Double(completedTranslationUnits) / Double(totalTranslationUnits), 1)
    }

    /// Number of target languages selected or planned for the current run.
    var selectedTargetCount: Int {
        if totalTargetLanguages > 0 {
            return totalTargetLanguages
        }

        return availableTargetLanguages.count
    }

    /// Number of strings shown in the per-target "Strings" metric.
    var progressStringsToTranslate: Int {
        if isTranslating || currentTargetTranslationUnits > 0 {
            return currentTargetTranslationUnits
        }

        return languageParser.stringsToTranslate.count
    }

    /// Elapsed time for the active or last completed translation run.
    var elapsedTranslationTime: TimeInterval {
        guard let translationStartedAt else {
            return 0
        }

        return max((translationEndedAt ?? timerDate).timeIntervalSince(translationStartedAt), 0)
    }

    /// User-facing elapsed time text.
    var elapsedTranslationText: String {
        guard translationStartedAt != nil else {
            return "Not started"
        }

        return formattedDuration(elapsedTranslationTime)
    }

    /// User-facing ETA text derived from completed unit throughput.
    ///
    /// Performance:
    /// The calculation is constant time and intentionally uses completed unit count
    /// rather than current string index so skipped targets do not distort the estimate.
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
