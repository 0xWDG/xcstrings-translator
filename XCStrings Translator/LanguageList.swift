//
//  LanguageList.swift
//  XCStrings Translator
//
//  Created by Wesley de Groot on 31/01/2025.
//

import Foundation

/// Display-name and identifier helpers for Translation framework languages.
///
/// These helpers centralize the identifier normalization rules from
/// `TranslationTargetsResolver` so pickers, settings, and tests show names for the
/// same catalog keys that are used when writing translations.
extension Locale.Language {
    /// Returns the localized display name for this language in a given UI locale.
    ///
    /// - Parameter locale: Locale used to localize the language name. Defaults to the
    ///   user's current locale.
    /// - Returns: A display name such as `Dutch` or `Portuguese (Brazil)`, or `nil`
    ///   when Foundation cannot resolve one.
    func localizedDisplayName(in locale: Locale = .current) -> String? {
        let identifier = systemDisplayIdentifier

        return locale.localizedString(forIdentifier: identifier) ??
            languageCode.flatMap {
                locale.localizedString(forLanguageCode: $0.identifier)
            }
    }

    /// Returns the language's name in its own locale.
    ///
    /// - Returns: A native display name such as `Nederlands`, or `nil` when Foundation
    ///   cannot resolve one.
    func nativeDisplayName() -> String? {
        let identifier = systemDisplayIdentifier
        let languageLocale = Locale(identifier: identifier)

        return languageLocale.localizedString(forIdentifier: identifier) ??
            languageCode.flatMap {
                languageLocale.localizedString(forLanguageCode: $0.identifier)
            }
    }

    /// Identifier used for display-name lookup and catalog matching.
    ///
    /// Falls back to `minimalIdentifier` only when the app cannot derive a catalog
    /// identifier. Keeping this consistent with translation writes avoids displaying
    /// one regional language while saving another key.
    var systemDisplayIdentifier: String {
        TranslationTargetsResolver.languageIdentifier(for: self) ??
            minimalIdentifier
    }

    /// Tests whether this language matches an identifier from settings or a catalog.
    ///
    /// - Parameter identifier: Identifier to compare, case-insensitively.
    /// - Returns: `true` when the identifier matches the app-normalized, minimal, or
    ///   maximal language identifier.
    func matchesLanguageIdentifier(_ identifier: String) -> Bool {
        let normalizedIdentifier = identifier.lowercased()

        return systemDisplayIdentifier.lowercased() == normalizedIdentifier ||
            minimalIdentifier.lowercased() == normalizedIdentifier ||
            maximalIdentifier.lowercased() == normalizedIdentifier
    }
}
