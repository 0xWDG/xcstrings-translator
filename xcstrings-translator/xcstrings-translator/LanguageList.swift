//
//  LanguageList.swift
//  xcstrings-translator
//
//  Created by Wesley de Groot on 31/01/2025.
//

import Foundation

struct Language {
    var identifier: String
    var name: String
    var localizedName: String
    var flag: String?
}

class LanguageList {
    var languages: [Language] = [
        .init(identifier: "de", name: "German", localizedName: "Deutsch", flag: "🇩🇪"),
        .init(identifier: "en", name: "English", localizedName: "English"),
        .init(identifier: "fr", name: "French", localizedName: "Français", flag: "🇫🇷"),
        .init(identifier: "it", name: "Italian", localizedName: "Italiano", flag: "🇮🇹"),
        .init(identifier: "es", name: "Spanish", localizedName: "Español", flag: "🇪🇸"),
        .init(identifier: "pt", name: "Portuguese (Portugal)", localizedName: "Português", flag: "🇵🇹"),
        .init(identifier: "pt-PT", name: "Portuguese (Portugal)", localizedName: "Português", flag: "🇵🇹"),
        .init(identifier: "pt-BR", name: "Portuguese (Brazil)", localizedName: "Português", flag: "🇧🇷"),
        .init(identifier: "ja", name: "Japanese", localizedName: "日本語", flag: "🇯🇵"),
        .init(identifier: "ko", name: "Korean", localizedName: "한국어", flag: "🇰🇷"),
        .init(identifier: "zh", name: "Chinese", localizedName: "中文", flag: "🇨🇳"),
        .init(identifier: "ru", name: "Russian", localizedName: "Русский", flag: "🇷🇺"),
        .init(identifier: "tr", name: "Turkish", localizedName: "Türkçe", flag: "🇹🇷"),
        .init(identifier: "sv", name: "Swedish", localizedName: "Svenska", flag: "🇸🇪"),
        .init(identifier: "da", name: "Danish", localizedName: "Dansk", flag: "🇩🇰"),
        .init(identifier: "pl", name: "Polish", localizedName: "Polski", flag: "🇵🇱"),
        .init(identifier: "fi", name: "Finnish", localizedName: "Suomen kieli", flag: "🇫🇮"),
        .init(identifier: "el", name: "Greek", localizedName: "Ελληνικά", flag: "🇬🇷"),
        .init(identifier: "hr", name: "Croatian", localizedName: "Hrvatski", flag: "🇭🇷"),
        .init(identifier: "cs", name: "Czech", localizedName: "Čeština", flag: "🇨🇿"),
        .init(identifier: "hu", name: "Hungarian", localizedName: "Magyar", flag: "🇭🇺"),
        .init(identifier: "nl", name: "Dutch", localizedName: "Nederlands", flag: "🇳🇱"),
        .init(identifier: "nb", name: "Norwegian", localizedName: "Norsk", flag: "🇳🇴"),
        .init(identifier: "bg", name: "Bulgarian", localizedName: "Български", flag: "🇧🇬"),
        .init(identifier: "ca", name: "Catalan", localizedName: "Català", flag: "🇪🇸"),
        .init(identifier: "sl", name: "Slovene", localizedName: "Slovenščina", flag: "🇸🇮"),
        .init(identifier: "sk", name: "Slovak", localizedName: "Slovensky", flag: "🇸🇰"),
        .init(identifier: "en", name: "English", localizedName: "English", flag: "🇺🇸"),
        .init(identifier: "ro", name: "Romanian", localizedName: "Română", flag: "🇷🇴"),
        .init(identifier: "vi", name: "Vietnamese", localizedName: "Tiếng Việt", flag: "🇻🇳"),
        .init(identifier: "uk", name: "English (British)", localizedName: "English (British)", flag: "🇬🇧"),
        .init(identifier: "id", name: "Indonesian", localizedName: "Indonesia", flag: "🇮🇩"),
        .init(identifier: "th", name: "Thai", localizedName: "ไทย", flag: "🇹🇭"),
        .init(identifier: "ar", name: "Arabic", localizedName: "اَلْعَرَبِيَّةُ", flag: "🇦🇪"),
        .init(identifier: "hi", name: "Hindi", localizedName: "हिन्दी", flag: "🇮🇳"),
    ]

    init() {

    }

    func language(for identifier: Locale.Language) -> Language? {
        return languages
            .first { $0.identifier == identifier.languageCode?.identifier }
    }
}
