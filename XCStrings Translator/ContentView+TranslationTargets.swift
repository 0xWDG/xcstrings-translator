//
//  ContentView+TranslationTargets.swift
//  XCStrings Translator
//
//  Created by Wesley de Groot on 21/06/2026.
//

import Foundation
import Translation

extension ContentView {
    func stringsToTranslate(for targetLanguage: Locale.Language?) -> [String] {
        stringsToTranslate(
            for: targetLanguage,
            skippingTranslated: languageParser.skipAlreadyTranslated
        )
    }

    func stringsToTranslate(
        for targetLanguage: Locale.Language?,
        skippingTranslated: Bool
    ) -> [String] {
        languageParser.stringsToTranslate(
            forLanguage: TranslationTargetsResolver.languageIdentifier(for: targetLanguage),
            skippingTranslated: skippingTranslated
        )
    }

    func totalTranslationUnits(for targetLanguages: [Locale.Language]) -> Int {
        totalTranslationUnits(
            for: targetLanguages,
            skippingTranslated: languageParser.skipAlreadyTranslated
        )
    }

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
