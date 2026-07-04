//
//  ContentView+TranslationTargets.swift
//  XCStrings Translator
//
//  Created by Wesley de Groot on 21/06/2026.
//

import Foundation
import Translation

/// Target-language filtering and work-count helpers for `ContentView`.
///
/// This extension separates Translation framework availability checks from the
/// run-execution code. It keeps the UI from offering source/target pairs that the
/// local system cannot translate.
extension ContentView {
    /// Returns pending source strings for a target using the current skip setting.
    ///
    /// - Parameter targetLanguage: Target language to inspect.
    /// - Returns: Source strings that should be translated for the target.
    func stringsToTranslate(for targetLanguage: Locale.Language?) -> [String] {
        stringsToTranslate(
            for: targetLanguage,
            skippingTranslated: languageParser.skipAlreadyTranslated
        )
    }

    /// Returns pending source strings for a target and explicit skip behavior.
    ///
    /// - Parameters:
    ///   - targetLanguage: Target language to inspect.
    ///   - skippingTranslated: Whether existing non-empty target values should be
    ///     excluded.
    /// - Returns: Source strings that should be translated for the target.
    func stringsToTranslate(
        for targetLanguage: Locale.Language?,
        skippingTranslated: Bool
    ) -> [String] {
        languageParser.stringsToTranslate(
            forLanguage: TranslationTargetsResolver.languageIdentifier(for: targetLanguage),
            skippingTranslated: skippingTranslated
        )
    }

    /// Counts work units for target languages using the current skip setting.
    ///
    /// - Parameter targetLanguages: Targets included in a run or estimate.
    /// - Returns: Total source-string/target-language units.
    func totalTranslationUnits(for targetLanguages: [Locale.Language]) -> Int {
        totalTranslationUnits(
            for: targetLanguages,
            skippingTranslated: languageParser.skipAlreadyTranslated
        )
    }

    /// Counts work units for target languages using explicit skip behavior.
    ///
    /// - Parameters:
    ///   - targetLanguages: Targets included in a run or estimate.
    ///   - skippingTranslated: Whether existing target values are excluded.
    /// - Returns: Total source-string/target-language units.
    func totalTranslationUnits(
        for targetLanguages: [Locale.Language],
        skippingTranslated: Bool
    ) -> Int {
        targetLanguages.reduce(0) { partialResult, targetLanguage in
            partialResult + stringsToTranslate(
                for: targetLanguage,
                skippingTranslated: skippingTranslated
            ).count
        }
    }

    /// Checks whether Apple's Translation framework can translate a source/target pair.
    ///
    /// - Parameters:
    ///   - source: Source language selected for the catalog.
    ///   - target: Candidate target language.
    /// - Returns: `true` for installed or supported pairs, `false` for unsupported or
    ///   future unknown statuses.
    func isTranslationPairAvailable(
        source: Locale.Language,
        target: Locale.Language
    ) async -> Bool {
        let status = await languageAvailability.status(from: source, to: target)

        switch status {
        case .installed, .supported:
            return true
        case .unsupported:
            logger.debug(
                """
                Skipping unsupported translation pair: \
                \(source.maximalIdentifier, privacy: .public)-\(target.maximalIdentifier, privacy: .public)
                """
            )
            return false
        @unknown default:
            return false
        }
    }

    /// Builds target picker options for the currently selected source language.
    ///
    /// - Returns: System-supported target languages that are not the same base language
    ///   as the source and pass Translation framework pair availability checks.
    ///
    /// Performance:
    /// Availability is checked sequentially to keep framework calls simple and avoid
    /// racing UI state changes during source-language updates.
    func availableSystemTargetLanguages() async -> [Locale.Language] {
        guard let sourceLanguage else {
            return []
        }

        var availableLanguages: [Locale.Language] = []

        for targetLanguage in supportedLanguages {
            guard TranslationTargetsResolver.languageIdentifier(for: targetLanguage) !=
                    TranslationTargetsResolver.languageIdentifier(for: sourceLanguage),
                  targetLanguage.languageCode?.identifier != sourceLanguage.languageCode?.identifier,
                  await isTranslationPairAvailable(source: sourceLanguage, target: targetLanguage) else {
                continue
            }

            availableLanguages.append(targetLanguage)
        }

        return availableLanguages
    }

    /// Filters a candidate target list to pairs compatible with the current source.
    ///
    /// - Parameter targetLanguages: Candidate targets, usually from the current picker
    ///   selection.
    /// - Returns: Targets that the Translation framework reports as installed or supported.
    ///
    /// Side Effects:
    /// Updates `status` while availability is being checked.
    @MainActor
    func compatibleTargetLanguages(
        from targetLanguages: [Locale.Language]
    ) async -> [Locale.Language] {
        guard let sourceLanguage else {
            return []
        }

        status = "Checking available translation languages"

        var compatibleLanguages: [Locale.Language] = []

        for targetLanguage in targetLanguages
        where await isTranslationPairAvailable(
            source: sourceLanguage,
            target: targetLanguage
        ) {
            compatibleLanguages.append(targetLanguage)
        }

        return compatibleLanguages
    }
}
