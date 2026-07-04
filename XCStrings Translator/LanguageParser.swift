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

/// Loads, mutates, and serializes an Xcode String Catalog.
///
/// Purpose:
/// `LanguageParser` is the app's model object for `.xcstrings` files. It keeps the
/// original catalog as a loose JSON dictionary so Xcode-owned metadata can round-trip
/// unchanged while the app updates only the `stringUnit` values it translates.
///
/// Responsibilities:
/// - Read a selected string catalog from disk.
/// - Track the source strings that are eligible for translation.
/// - Cache which target languages already contain translated values.
/// - Insert Translation framework responses back into the catalog.
/// - Encode the modified catalog for saving or exporting.
///
/// Dependencies:
/// Uses `Foundation.JSONSerialization` for format-preserving JSON access,
/// `Translation` for response types, `UserDefaults` for settings, and `OSLog` for
/// diagnostics. The class is `@MainActor` because SwiftUI observes its published
/// properties and because file operations are initiated from UI actions.
///
/// Thread Safety:
/// All mutable state is isolated to the main actor. Callers should `await` main-actor
/// access when invoking this type from asynchronous translation tasks.
@MainActor
class LanguageParser: ObservableObject {
    /// Settings sentinel used when the default target should be every compatible language.
    static let allLanguagesDefaultTargetIdentifier = "all"

    /// Outcome of saving the loaded catalog back to its original URL.
    ///
    /// `skippedTesting` is not an error. It means Test Mode intentionally suppressed
    /// disk writes so contributors can exercise translation behavior on real files.
    enum SaveResult {
        case saved
        case skippedTesting
    }

    /// Errors that can occur while saving the currently loaded catalog.
    enum SaveError: LocalizedError {
        /// No file has been loaded, so there is no original URL to overwrite.
        case noLoadedFile
        /// The in-memory dictionary cannot be represented as a valid JSON catalog.
        case invalidCatalog

        /// Human-readable description shown in logs and UI status messages.
        var errorDescription: String? {
            switch self {
            case .noLoadedFile:
                return "No loaded string catalog file is available."
            case .invalidCatalog:
                return "The string catalog could not be encoded."
            }
        }
    }

    /// String Catalog state written for newly created or replaced translations.
    ///
    /// Xcode uses these raw values in `.xcstrings` files. Keeping the enum raw-value
    /// backed avoids stringly typed writes in the rest of the parser.
    public enum LPState: String, CaseIterable, Identifiable {
        /// Translation is considered complete.
        case translated = "translated"
        /// Translation exists but should be reviewed by a human before shipping.
        case needsReview = "needs_review"

        /// Stable identity for SwiftUI pickers.
        var id: String { return self.rawValue }

        /// Localized display name used in Settings.
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

    /// Cache of catalog keys that already have non-empty translations, grouped by language identifier.
    ///
    /// Performance:
    /// The translation run asks for pending strings repeatedly, once per target
    /// language and after every completed response. Caching avoids walking the full
    /// nested JSON tree for each query.
    var translatedStringKeysByLanguage: [String: Set<String>] = [:]

    /// Raw JSON dictionary for the loaded `.xcstrings` catalog.
    ///
    /// Xcode may add new keys or nested structures over time. Storing the catalog as
    /// `[String: Any]` is intentional: it lets this app preserve unknown metadata while
    /// replacing only the values it owns.
    var languageDictionary: [String: Any] = [:]
    /// Source strings that can be sent to Apple's Translation framework.
    @Published var stringsToTranslate: [String] = []
    /// Source language identifier read from the catalog or inferred by the UI.
    @Published var sourceLanguage: String = "en"
    /// Security-scoped URL of the currently loaded catalog.
    @Published var fileURL: URL?
    /// State written to each translated `stringUnit`.
    @Published var state: LPState = .translated {
        didSet {
            UserDefaults.standard.set(self.state.rawValue, forKey: "state")
            logger.debug("Updated translations state to \(self.state.humanReadableName.stringValue)")
        }
    }

    /// Whether existing target-language values should be left untouched during normal runs.
    @Published var skipAlreadyTranslated: Bool = true {
        didSet {
            UserDefaults.standard.set(self.skipAlreadyTranslated, forKey: "skipAlreadyTranslated")
            logger.debug("Updated skip already translated to \(self.skipAlreadyTranslated)")
        }
    }

    /// Identifier selected by default in the target-language picker.
    @Published var defaultTargetLanguageIdentifier: String = allLanguagesDefaultTargetIdentifier {
        didSet {
            UserDefaults.standard.set(
                self.defaultTargetLanguageIdentifier,
                forKey: "defaultTargetLanguageIdentifier"
            )
            logger.debug("Updated default target language to \(self.defaultTargetLanguageIdentifier)")
        }
    }

    /// Whether the app should save a checkpoint after each completed target language.
    @Published var autoSaveTranslations: Bool = false {
        didSet {
            UserDefaults.standard.set(self.autoSaveTranslations, forKey: "autoSaveTranslations")
            logger.debug("Updated auto save translations to \(self.autoSaveTranslations)")
        }
    }

    /// Prevents writes to the loaded source file while still allowing export.
    ///
    /// Side Effects:
    /// The value is persisted in `UserDefaults` so it survives relaunches.
    @Published public var isTesting: Bool = false {
        didSet {
            UserDefaults.standard.set(self.isTesting, forKey: "isTesting")
            logger.debug("Updated isTesting to \(self.isTesting ? "Testing" : "Not Testing")")
        }
    }

    /// Creates a parser and restores persisted user preferences.
    ///
    /// Side Effects:
    /// Reads `UserDefaults`. No file IO is performed until `load(file:)`.
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

    /// Clears the loaded catalog and all derived translation state.
    ///
    /// Side Effects:
    /// Resets published properties, which invalidates observing SwiftUI views.
    func reset() {
        languageDictionary = [:]
        stringsToTranslate = []
        sourceLanguage = "en"
        fileURL = nil
        translatedStringKeysByLanguage = [:]
    }

    /// Loads and parses a `.xcstrings` file.
    ///
    /// - Parameter url: File URL selected by the user, Finder, or an Open URL event.
    ///
    /// Possible Errors:
    /// Errors are logged instead of thrown because this method is called directly by UI
    /// event handlers. A failed load leaves the parser in its reset state.
    ///
    /// Side Effects:
    /// Starts and stops security-scoped resource access when needed, updates
    /// `fileURL`, `languageDictionary`, `stringsToTranslate`, and
    /// `translatedStringKeysByLanguage`.
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

    /// Saves the current catalog back to the file it was loaded from.
    ///
    /// - Returns: `.saved` when bytes were written, or `.skippedTesting` when Test Mode
    ///   intentionally prevented mutation of the original file.
    /// - Throws: `SaveError.noLoadedFile` when no file URL is available, plus any file
    ///   or JSON encoding error thrown by `encodedData()` or `Data.write`.
    ///
    /// Side Effects:
    /// Writes the catalog atomically to disk unless Test Mode is enabled.
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

    /// Adds a Translation framework response to the loaded catalog.
    ///
    /// - Parameter response: The completed Translation framework response containing
    ///   source text, target text, and target language.
    ///
    /// Side Effects:
    /// Mutates `languageDictionary` and updates `translatedStringKeysByLanguage` for
    /// the response target language.
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

    /// Adds or replaces one target-language localization in the loaded catalog.
    ///
    /// - Parameters:
    ///   - rawTranslation: Text returned by the Translation framework.
    ///   - forLanguage: Catalog language identifier to write, for example `nl` or `pt-BR`.
    ///   - original: Source string key in the catalog's top-level `strings` dictionary.
    ///
    /// Side Effects:
    /// Mutates the in-memory catalog, preserves existing localization metadata where
    /// possible, and marks the source key as translated for `forLanguage`.
    ///
    /// Implementation Notes:
    /// Translation can alter printf-style placeholders or lowercase sentence-initial
    /// words. The parser repairs placeholders first, then applies a conservative
    /// capitalization adjustment so UI strings keep their original style.
    func add(translation rawTranslation: String, forLanguage: String, original: String) {
        if var strings = languageDictionary["strings"] as? [String: Any],
           var item = strings[original] as? [String: Any] {
            let normalizedTranslation = preservingFormatSpecifiers(
                in: rawTranslation.replacingOccurrences(of: "%Lld", with: "%lld"),
                matching: original
            )
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

    /// Mirrors the source string's initial capitalization when the source begins uppercase.
    ///
    /// - Parameters:
    ///   - translation: Candidate translated text.
    ///   - original: Source catalog key used as the casing reference.
    /// - Returns: `translation` with its first character uppercased only when the
    ///   source starts with an uppercase character.
    ///
    /// This deliberately avoids lowercasing anything. Some languages and product names
    /// require uppercase even when English source text does not.
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

    /// Extracts translatable source strings and caches existing target-language coverage.
    ///
    /// Side Effects:
    /// Rebuilds `stringsToTranslate` and `translatedStringKeysByLanguage`.
    ///
    /// Performance:
    /// This performs one full traversal of the loaded catalog. Subsequent
    /// target-specific queries use the cache built here.
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

    /// Returns source strings that still need work for a target language.
    ///
    /// - Parameters:
    ///   - languageIdentifier: Target catalog identifier, or `nil` when no target is
    ///     selected yet.
    ///   - skippingTranslated: Whether existing non-empty target values should be
    ///     excluded.
    /// - Returns: Non-empty source strings eligible for translation.
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

    /// Encoded catalog data suitable for SwiftUI export.
    ///
    /// Returns empty data if encoding fails because `FileDocument` expects a
    /// non-throwing value. The throwing `encodedData()` method is used for save paths
    /// that can surface an error to the UI.
    var data: Data {
        do {
            return try encodedData()
        } catch {
            logger.error("Failed to encode string catalog: \(error.localizedDescription, privacy: .public)")
            return Data()
        }
    }

    /// Encodes the current catalog dictionary as pretty-printed JSON.
    ///
    /// - Returns: JSON bytes for the modified `.xcstrings` file.
    /// - Throws: Any `JSONSerialization` error if the dictionary is not valid JSON.
    ///
    /// Side Effects:
    /// None. Callers decide whether to export, save, or discard the resulting data.
    func encodedData() throws -> Data {
        try JSONSerialization.data(
            withJSONObject: languageDictionary,
            options: .prettyPrinted
        )
    }
}
