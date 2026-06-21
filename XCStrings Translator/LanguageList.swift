//
//  LanguageList.swift
//  XCStrings Translator
//
//  Created by Wesley de Groot on 31/01/2025.
//

import Foundation
import SwiftUI

final class LanguageList {
    struct Language {
        var identifier: String
        var name: String
        var localizedName: String
        var flag: String?
    }

    private let languages: [Language] = [
        .init(
            identifier: "de",
            name: NSLocalizedString("German", comment: ""),
            localizedName: "Deutsch",
            flag: "🇩🇪"
        ),
        .init(
            identifier: "en-US",
            name: NSLocalizedString("English (US)", comment: ""),
            localizedName: "English (US)",
            flag: "🇺🇸"
        ),
        .init(
            identifier: "fr",
            name: NSLocalizedString("French", comment: ""),
            localizedName: "Français",
            flag: "🇫🇷"
        ),
        .init(
            identifier: "it",
            name: NSLocalizedString("Italian", comment: ""),
            localizedName: "Italiano",
            flag: "🇮🇹"
        ),
        .init(
            identifier: "es",
            name: NSLocalizedString("Spanish", comment: ""),
            localizedName: "Español",
            flag: "🇪🇸"
        ),
        .init(
            identifier: "pt",
            name: NSLocalizedString("Portuguese (Portugal)", comment: ""),
            localizedName: "Português",
            flag: "🇵🇹"
        ),
        .init(
            identifier: "pt-PT",
            name: NSLocalizedString("Portuguese (Portugal)", comment: ""),
            localizedName: "Português",
            flag: "🇵🇹"
        ),
        .init(
            identifier: "pt-BR",
            name: NSLocalizedString("Portuguese (Brazil)", comment: ""),
            localizedName: "Português",
            flag: "🇧🇷"
        ),
        .init(
            identifier: "ja",
            name: NSLocalizedString("Japanese", comment: ""),
            localizedName: "日本語",
            flag: "🇯🇵"
        ),
        .init(
            identifier: "ko",
            name: NSLocalizedString("Korean", comment: ""),
            localizedName: "한국어",
            flag: "🇰🇷"
        ),
        .init(
            identifier: "zh",
            name: NSLocalizedString("Chinese", comment: ""),
            localizedName: "中文",
            flag: "🇨🇳"
        ),
        .init(
            identifier: "ru",
            name: NSLocalizedString("Russian", comment: ""),
            localizedName: "Русский",
            flag: "🇷🇺"
        ),
        .init(
            identifier: "tr",
            name: NSLocalizedString("Turkish", comment: ""),
            localizedName: "Türkçe",
            flag: "🇹🇷"
        ),
        .init(
            identifier: "sv",
            name: NSLocalizedString("Swedish", comment: ""),
            localizedName: "Svenska",
            flag: "🇸🇪"
        ),
        .init(
            identifier: "da",
            name: NSLocalizedString("Danish", comment: ""),
            localizedName: "Dansk",
            flag: "🇩🇰"
        ),
        .init(
            identifier: "pl",
            name: NSLocalizedString("Polish", comment: ""),
            localizedName: "Polski",
            flag: "🇵🇱"
        ),
        .init(
            identifier: "fi",
            name: NSLocalizedString("Finnish", comment: ""),
            localizedName: "Suomen kieli",
            flag: "🇫🇮"
        ),
        .init(
            identifier: "el",
            name: NSLocalizedString("Greek", comment: ""),
            localizedName: "Ελληνικά",
            flag: "🇬🇷"
        ),
        .init(
            identifier: "hr",
            name: NSLocalizedString("Croatian", comment: ""),
            localizedName: "Hrvatski",
            flag: "🇭🇷"
        ),
        .init(
            identifier: "cs",
            name: NSLocalizedString("Czech", comment: ""),
            localizedName: "Čeština",
            flag: "🇨🇿"
        ),
        .init(
            identifier: "hu",
            name: NSLocalizedString("Hungarian", comment: ""),
            localizedName: "Magyar",
            flag: "🇭🇺"
        ),
        .init(
            identifier: "nl",
            name: NSLocalizedString("Dutch", comment: ""),
            localizedName: "Nederlands",
            flag: "🇳🇱"
        ),
        .init(
            identifier: "nb",
            name: NSLocalizedString("Norwegian", comment: ""),
            localizedName: "Norsk",
            flag: "🇳🇴"
        ),
        .init(
            identifier: "bg",
            name: NSLocalizedString("Bulgarian", comment: ""),
            localizedName: "Български",
            flag: "🇧🇬"
        ),
        .init(
            identifier: "ca",
            name: NSLocalizedString("Catalan", comment: ""),
            localizedName: "Català",
            flag: "🇪🇸"
        ),
        .init(
            identifier: "sl",
            name: NSLocalizedString("Slovene", comment: ""),
            localizedName: "Slovenščina",
            flag: "🇸🇮"
        ),
        .init(
            identifier: "sk",
            name: NSLocalizedString("Slovak", comment: ""),
            localizedName: "Slovensky",
            flag: "🇸🇰"
        ),
        .init(
            identifier: "en",
            name: NSLocalizedString("English", comment: ""),
            localizedName: "English",
            flag: "🇺🇸"
        ),
        .init(
            identifier: "ro",
            name: NSLocalizedString("Romanian", comment: ""),
            localizedName: "Română",
            flag: "🇷🇴"
        ),
        .init(
            identifier: "vi",
            name: NSLocalizedString("Vietnamese", comment: ""),
            localizedName: "Tiếng Việt",
            flag: "🇻🇳"
        ),
        .init(
            identifier: "uk",
            name: NSLocalizedString("English (British)", comment: ""),
            localizedName: "English (British)",
            flag: "🇬🇧"
        ),
        .init(
            identifier: "id",
            name: NSLocalizedString("Indonesian", comment: ""),
            localizedName: "Indonesia",
            flag: "🇮🇩"
        ),
        .init(
            identifier: "th",
            name: NSLocalizedString("Thai", comment: ""),
            localizedName: "ไทย",
            flag: "🇹🇭"
        ),
        .init(
            identifier: "ar",
            name: NSLocalizedString("Arabic", comment: ""),
            localizedName: "اَلْعَرَبِيَّةُ",
            flag: "🇦🇪"
        ),
        .init(
            identifier: "hi",
            name: NSLocalizedString("Hindi", comment: ""),
            localizedName: "हिन्दी",
            flag: "🇮🇳"
        )
    ]

    private let languagesByIdentifier: [String: Language]

    init() {
        languagesByIdentifier = Dictionary(
            uniqueKeysWithValues: languages.map { ($0.identifier, $0) }
        )
    }

    func language(for identifier: Locale.Language) -> Language? {
        if let targetIdentifier = TranslationTargetsResolver.languageIdentifier(for: identifier),
           let exactLanguage = languagesByIdentifier[targetIdentifier] {
            return exactLanguage
        }

        if let languageCode = identifier.languageCode?.identifier {
            return languagesByIdentifier[languageCode]
        }

        return nil
    }
}
