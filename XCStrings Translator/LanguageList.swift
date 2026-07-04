//
//  LanguageList.swift
//  XCStrings Translator
//
//  Created by Wesley de Groot on 31/01/2025.
//

import Foundation

extension Locale.Language {
    func localizedDisplayName(in locale: Locale = .current) -> String? {
        let identifier = systemDisplayIdentifier

        return locale.localizedString(forIdentifier: identifier) ??
            languageCode.flatMap {
                locale.localizedString(forLanguageCode: $0.identifier)
            }
    }

    func nativeDisplayName() -> String? {
        let identifier = systemDisplayIdentifier
        let languageLocale = Locale(identifier: identifier)

        return languageLocale.localizedString(forIdentifier: identifier) ??
            languageCode.flatMap {
                languageLocale.localizedString(forLanguageCode: $0.identifier)
            }
    }

    var systemDisplayIdentifier: String {
        TranslationTargetsResolver.languageIdentifier(for: self) ??
            minimalIdentifier
    }

    func matchesLanguageIdentifier(_ identifier: String) -> Bool {
        let normalizedIdentifier = identifier.lowercased()

        return systemDisplayIdentifier.lowercased() == normalizedIdentifier ||
            minimalIdentifier.lowercased() == normalizedIdentifier ||
            maximalIdentifier.lowercased() == normalizedIdentifier
    }
}

@available(*, deprecated, message: "Use Locale.Language.localizedDisplayName(in:) instead.")
final class LanguageList {
    struct Language {
        var identifier: String
        var name: String
        var localizedName: String
        var flag: String?
    }

    private let locale: Locale

    init(locale: Locale = .current) {
        self.locale = locale
    }

    func language(for language: Locale.Language) -> Language? {
        guard let name = language.localizedDisplayName(in: locale) else {
            return nil
        }

        let identifier = language.systemDisplayIdentifier

        return Language(
            identifier: identifier,
            name: name,
            localizedName: language.nativeDisplayName() ?? name,
            flag: language.region.flatMap { flag(forRegion: $0.identifier) }
        )
    }

    private func flag(forRegion region: String) -> String? {
        let base = UnicodeScalar("🇦").value
        let scalars = region.uppercased().unicodeScalars

        guard scalars.count == 2,
              scalars.allSatisfy({ ("A"..."Z").contains(Character($0)) }) else {
            return nil
        }

        return String(
            String.UnicodeScalarView(
                scalars.compactMap {
                    UnicodeScalar(base + $0.value - UnicodeScalar("A").value)
                }
            )
        )
    }
}
