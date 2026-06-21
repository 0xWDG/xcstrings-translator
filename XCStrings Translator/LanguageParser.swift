//
//  LanguageParser.swift
//  XCStrings Translator
//
//  Created by Wesley de Groot on 31/01/2025.
//

import Foundation
import OSLog
import Translation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
class LanguageParser: ObservableObject {
    static let allLanguagesDefaultTargetIdentifier = "all"

    enum SaveResult {
        case saved
        case skippedTesting
    }

    enum SaveError: LocalizedError {
        case noLoadedFile
        case invalidCatalog

        var errorDescription: String? {
            switch self {
            case .noLoadedFile:
                return "No loaded string catalog file is available."
            case .invalidCatalog:
                return "The string catalog could not be encoded."
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

    // Cache translated keys by language so "skip already translated" does not need to
    // walk the full JSON tree for every target language during a run.
    var translatedStringKeysByLanguage: [String: Set<String>] = [:]

    // .xcstrings supports nested and evolving JSON structures. Keep this as a loose
    // dictionary so unknown Xcode metadata survives load, translation, and export.
    var languageDictionary: [String: Any] = [:]
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

    @Published var autoSaveTranslations: Bool = false {
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
        autoSaveTranslations = UserDefaults.standard.object(
            forKey: "autoSaveTranslations"
        ) as? Bool ?? true
    }

    func reset() {
        languageDictionary = [:]
        stringsToTranslate = []
        sourceLanguage = "en"
        fileURL = nil
        translatedStringKeysByLanguage = [:]
    }

    func load(file url: URL) {
        reset()

        fileURL = url

        // Files opened through Finder or the document picker may be security-scoped
        // sandbox URLs. Access must stay active while reading the file.
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            guard let dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                throw SaveError.invalidCatalog
            }

            languageDictionary = dict
            logger.debug("Loaded string catalog with \(data.count) bytes")
            parse()
        } catch {
            logger.error("Serialization error: \(error.localizedDescription, privacy: .public)")
        }
    }

    func saveToLoadedFile() throws -> SaveResult {
        // Test Mode lets contributors verify translation behavior without mutating the
        // user's original catalog on disk.
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

        try encodedData().write(to: fileURL, options: .atomic)
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
            let normalizedTranslation = rawTranslation
                .replacingOccurrences(of: "%Lld", with: "%lld")
            let translation = capitalizationAdjustedTranslation(
                normalizedTranslation,
                matchingCapitalizationOf: original
            )

            if var localizations = item["localizations"] as? [String: Any] {
                logger.debug(
                    // swiftlint:disable:next line_length
                    "[\(forLanguage)] Updated \"\(original)\" with translation \"\(translation)\" and state: \(self.state.rawValue)."
                )
                localizations[forLanguage] = updatedLocalization(
                    existingLocalization: localizations[forLanguage],
                    translation: translation
                )

                // https://mastodon.social/@zhenyi/113969196950076700
                item["localizations"] = localizations
                strings[original] = item
                languageDictionary["strings"] = strings
                translatedStringKeysByLanguage[forLanguage, default: []].insert(original)
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
                translatedStringKeysByLanguage[forLanguage, default: []].insert(original)
                return
            }
        }

        logger.error("Failed to get strings")
    }

    func capitalizationAdjustedTranslation(
        _ translation: String,
        matchingCapitalizationOf original: String
    ) -> String {
        guard original.first?.isUppercase == true,
              let firstCharacter = translation.first else {
            return translation
        }

        return firstCharacter.uppercased() + String(translation.dropFirst())
    }

    func parse() {
        stringsToTranslate = []
        translatedStringKeysByLanguage = [:]

        if let strings = languageDictionary["strings"] as? [String: Any] {
            for (key, value) in strings where !key.isEmpty {
                guard let value = value as? [String: Any] else { continue }

                // Xcode can mark catalog entries as not translatable. Keep those out
                // of the source list entirely so they never reach Translation.
                if value["shouldTranslate"] as? Bool ?? true {
                    stringsToTranslate.append(key)
                    cacheTranslatedLanguages(in: value, for: key)
                }
            }
        }
    }

    func stringsToTranslate(
        forLanguage languageIdentifier: String?,
        skippingTranslated: Bool
    ) -> [String] {
        // If no target language is known yet, return the raw translatable source list.
        // The target-specific skip pass runs once the user starts translating.
        guard skippingTranslated,
              let languageIdentifier else {
            return stringsToTranslate.filter { !$0.isEmpty }
        }

        let translatedStringKeys = translatedStringKeysByLanguage[languageIdentifier, default: []]
        return stringsToTranslate.filter { string in
            !string.isEmpty && !translatedStringKeys.contains(string)
        }
    }

    var data: Data {
        do {
            return try encodedData()
        } catch {
            logger.error("Failed to encode string catalog: \(error.localizedDescription, privacy: .public)")
            return Data()
        }
    }

    func encodedData() throws -> Data {
        try JSONSerialization.data(
            withJSONObject: languageDictionary,
            options: .prettyPrinted
        )
    }
}
