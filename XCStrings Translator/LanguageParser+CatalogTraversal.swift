//
//  LanguageParser+CatalogTraversal.swift
//  XCStrings Translator
//
//  Created by Wesley de Groot on 21/06/2026.
//

import Foundation

extension LanguageParser {
    func updatedLocalization(
        existingLocalization: Any?,
        translation: String
    ) -> [String: Any] {
        let stringUnit: [String: Any] = [
            "state": "\(state.rawValue)",
            "value": translation
        ]

        guard var localization = existingLocalization as? [String: Any] else {
            return [
                "stringUnit": stringUnit
            ]
        }

        // Preserve any metadata or variation dictionaries Xcode already wrote, while
        // replacing the simple stringUnit used by this app.
        localization["stringUnit"] = stringUnit
        return localization
    }

    func cacheTranslatedLanguages(in item: [String: Any], for key: String) {
        guard let localizations = item["localizations"] as? [String: Any] else {
            return
        }

        for (languageIdentifier, localization) in localizations {
            let translatedValues = stringUnitValues(in: localization)

            // Variations are only considered translated when every nested stringUnit
            // has a non-empty value. This prevents skipping partially translated plurals.
            if !translatedValues.isEmpty && translatedValues.allSatisfy({ !$0.isEmpty }) {
                translatedStringKeysByLanguage[languageIdentifier, default: []].insert(key)
            }
        }
    }

    func stringUnitValues(in value: Any) -> [String] {
        // .xcstrings can store stringUnit directly or nested below variations such as
        // plural/device-width rules. Recursing keeps the skip logic format-agnostic.
        if let dictionary = value as? [String: Any] {
            if let stringUnit = dictionary["stringUnit"] as? [String: Any],
               let stringValue = stringUnit["value"] as? String {
                return [stringValue]
            }

            return dictionary.values.flatMap { stringUnitValues(in: $0) }
        }

        if let array = value as? [Any] {
            return array.flatMap { stringUnitValues(in: $0) }
        }

        return []
    }
}
