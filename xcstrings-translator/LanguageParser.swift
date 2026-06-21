//
//  LanguageParser.swift
//  xcstrings-translator
//
//  Created by Wesley de Groot on 31/01/2025.
//

import Foundation
import OSLog
import Translation
import SwiftUI
import UniformTypeIdentifiers

class LanguageParser: ObservableObject {
    static let allLanguagesDefaultTargetIdentifier = "all"

    enum SaveResult {
        case saved
        case skippedTesting
    }

    enum SaveError: LocalizedError {
        case noLoadedFile

        var errorDescription: String? {
            switch self {
            case .noLoadedFile:
                return "No loaded string catalog file is available."
            }
        }
    }

    public enum LPState: String, CaseIterable, Identifiable {
        case translated = "translated"
        case needsReview = "needs_review"

        var id: String { return self.rawValue }

        var humanReadableName: LocalizedStringKey {
            switch self {
            case .translated:
                return "Translated"
            case .needsReview:
                return "Needs review"
            }
        }
    }

    private let logger = Logger(
        subsystem: "nl.wesleydegroot.xcstrings-translator",
        category: "LanguageParser"
    )

    @Published var languageDictionary: [String: Any] = [:]
    @Published var stringsToTranslate: [String] = []
    @Published var sourceLanguage: String = "en"
    @Published var fileURL: URL?
    @Published var state: LPState = .translated {
        didSet {
            UserDefaults.standard.set(self.state.rawValue, forKey: "state")
            logger.debug("Updated translations state to \(self.state.humanReadableName.stringValue)")
        }
    }

    @Published var skipAlreadyTranslated: Bool = true {
        didSet {
            UserDefaults.standard.set(self.skipAlreadyTranslated, forKey: "skipAlreadyTranslated")
            logger.debug("Updated skip already translated to \(self.skipAlreadyTranslated)")
        }
    }

    @Published var defaultTargetLanguageIdentifier: String = allLanguagesDefaultTargetIdentifier {
        didSet {
            UserDefaults.standard.set(
                self.defaultTargetLanguageIdentifier,
                forKey: "defaultTargetLanguageIdentifier"
            )
            logger.debug("Updated default target language to \(self.defaultTargetLanguageIdentifier)")
        }
    }

    @Published var autoSaveTranslations: Bool = true {
        didSet {
            UserDefaults.standard.set(self.autoSaveTranslations, forKey: "autoSaveTranslations")
            logger.debug("Updated auto save translations to \(self.autoSaveTranslations)")
        }
    }

    @Published public var isTesting: Bool = false {
        didSet {
            UserDefaults.standard.set(self.isTesting, forKey: "isTesting")
            logger.debug("Updated isTesting to \(self.isTesting ? "Testing" : "Not Testing")")
        }
    }

    init() {
        isTesting = UserDefaults.standard.bool(forKey: "isTesting")
        state = LPState(
            rawValue: UserDefaults.standard
                .string(forKey: "state") ?? "translated"
        ) ?? .translated
        skipAlreadyTranslated = UserDefaults.standard.object(
            forKey: "skipAlreadyTranslated"
        ) as? Bool ?? true
        defaultTargetLanguageIdentifier = UserDefaults.standard.string(
            forKey: "defaultTargetLanguageIdentifier"
        ) ?? Self.allLanguagesDefaultTargetIdentifier
        autoSaveTranslations = UserDefaults.standard.bool(forKey: "autoSaveTranslations")
    }

    func reset() {
        languageDictionary = [:]
        stringsToTranslate = []
        sourceLanguage = "en"
        fileURL = nil
    }

    func load(file url: URL) {
        reset()

        fileURL = url

        do {
            if let data = try? Data(contentsOf: url),
               let dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                languageDictionary = dict
                print("Dict", dict)

                parse()
            }

        } catch {
            logger.error("Serialization error: \(error.localizedDescription, privacy: .public)")
        }
    }

    func saveToLoadedFile() throws -> SaveResult {
        guard !isTesting else {
            return .skippedTesting
        }

        guard let fileURL else {
            throw SaveError.noLoadedFile
        }

        let didStartAccessing = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        try data.write(to: fileURL, options: .atomic)
        return .saved
    }

    func add(translation response: TranslationSession.Response) {
        if let identifier = TranslationTargetsResolver.languageIdentifier(
            for: response.targetLanguage
        ) {
            self.add(
                translation: response.targetText,
                forLanguage: identifier,
                original: response.sourceText
            )
        }
    }

    func add(translation rawTranslation: String, forLanguage: String, original: String) {
        if var strings = languageDictionary["strings"] as? [String: Any],
           var item = strings[original] as? [String: Any] {
            let translation = rawTranslation
                .replacingOccurrences(of: "%Lld", with: "%lld")

            // { "strings": { "string": { shouldtranslate: false?
            // "localizations" : { "nl" : { "stringUnit" : { "state" : "translated", "value" : "%@"

            if var localizations = item["localizations"] as? [String: Any] {
                logger.debug(
                    // swiftlint:disable:next line_length
                    "[\(forLanguage)] Updated \"\(original)\" with translation \"\(translation)\" and state: \(self.state.rawValue)."
                )
                localizations[forLanguage] = ["stringUnit": ["state": "\(state.rawValue)", "value": translation]]

                // https://mastodon.social/@zhenyi/113969196950076700
                item["localizations"] = localizations
                strings[original] = item
                languageDictionary["strings"] = strings
                return
            } else {
                logger.debug(
                    // swiftlint:disable:next line_length
                    "[\(forLanguage)] Created localizations for \"\(original)\" with translation \"\(translation)\" and state \(self.state.rawValue)."
                )
                item["localizations"] = [
                    forLanguage: [
                        "stringUnit": [
                            "state": "\(state.rawValue)",
                            "value": translation
                        ]
                    ]
                ]

                // https://mastodon.social/@zhenyi/113969196950076700
                strings[original] = item
                languageDictionary["strings"] = strings
                return
            }
        }

        print("Failed to get strings")
    }

    func parse() {
        stringsToTranslate = []

        if let strings = languageDictionary["strings"] as? [String: Any] {
            for (key, value) in strings where !key.isEmpty {
                guard let value = value as? [String: Any] else { continue }

                if value["shouldTranslate"] as? Bool ?? true {
                    stringsToTranslate.append(key)
                }
            }
        }
    }

    func stringsToTranslate(
        forLanguage languageIdentifier: String?,
        skippingTranslated: Bool
    ) -> [String] {
        guard skippingTranslated,
              let languageIdentifier else {
            return stringsToTranslate.filter { !$0.isEmpty }
        }

        return stringsToTranslate.filter { string in
            !string.isEmpty && !hasTranslation(for: string, languageIdentifier: languageIdentifier)
        }
    }

    private func hasTranslation(for string: String, languageIdentifier: String) -> Bool {
        guard let strings = languageDictionary["strings"] as? [String: Any],
              let item = strings[string] as? [String: Any],
              let localizations = item["localizations"] as? [String: Any],
              let localization = localizations[languageIdentifier] as? [String: Any] else {
            return false
        }

        let translatedValues = stringUnitValues(in: localization)
        return !translatedValues.isEmpty && translatedValues.allSatisfy { !$0.isEmpty }
    }

    private func stringUnitValues(in value: Any) -> [String] {
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

    var data: Data {
        try! JSONSerialization.data(
            // swiftlint:disable:previous force_try
            withJSONObject: languageDictionary,
            options: .prettyPrinted
        )
    }
}
