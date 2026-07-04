//
//  LanguageParser+CatalogTraversal.swift
//  XCStrings Translator
//
//  Created by Wesley de Groot on 21/06/2026.
//

import Foundation

/// Helpers for traversing and updating nested `.xcstrings` catalog structures.
///
/// Xcode String Catalogs can contain direct `stringUnit` values as well as nested
/// variations for plurals or device traits. These helpers keep that traversal logic
/// out of the main parser methods.
extension LanguageParser {
    /// Builds a localization dictionary that preserves existing metadata.
    ///
    /// - Parameters:
    ///   - existingLocalization: Existing localization value from the catalog, if any.
    ///   - translation: New translated string value to write.
    /// - Returns: Localization dictionary containing the replacement `stringUnit`.
    ///
    /// Side Effects:
    /// None. The caller writes the returned dictionary back into the catalog.
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

    /// Caches languages that already contain complete non-empty translations for a key.
    ///
    /// - Parameters:
    ///   - item: One entry from the catalog's top-level `strings` dictionary.
    ///   - key: Source string key represented by `item`.
    ///
    /// Side Effects:
    /// Mutates `translatedStringKeysByLanguage`.
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

    /// Recursively extracts all `stringUnit.value` strings below a catalog value.
    ///
    /// - Parameter value: Any JSON value from a localization subtree.
    /// - Returns: String-unit values found directly or inside nested dictionaries/arrays.
    ///
    /// Implementation Notes:
    /// Returning every nested value lets skip logic treat plurals conservatively: a
    /// plural localization is considered complete only when all nested string units are
    /// present and non-empty.
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
