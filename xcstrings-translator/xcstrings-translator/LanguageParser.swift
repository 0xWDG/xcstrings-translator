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
    public enum LPState: String, CaseIterable, Identifiable {
        case translated = "translated"
        case needsReview = "needs_review"

        var id: String { return self.rawValue }

        var humanReadableName: String {
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
    @Published var shouldTranslate: [Bool] = []
    @Published var sourceLanguage: String = "en"
    @Published var fileURL: URL?
    @Published var state: LPState = .translated {
        didSet {
            UserDefaults.standard.set(self.state.rawValue, forKey: "state")
            logger.debug("Updated translations state to \(self.state.humanReadableName)")
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
    }

    func reset() {
        languageDictionary = [:]
        stringsToTranslate = []
        shouldTranslate = []
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

    func save() {
        guard var fileURL else {
            logger.error("No file URL set.")
            return
        }

        do {
            let jsonData = try JSONSerialization.data(
                withJSONObject: languageDictionary,
                options: .prettyPrinted
            )

            print(String(data: jsonData, encoding: .utf8) ?? "")

            if isTesting {
                logger.debug("We are testing, appending _test.json to the filename")

                guard let newFileURL = URL(
                    string:
                        fileURL
                        .relativeString
                        .split(separator: "/")
                        .dropLast()
                        .joined(separator: "/")
                    + "/test.json"
                ) else {
                    fatalError("Failed to create new file URL")
                }

                fileURL = newFileURL
            }

            try jsonData.write(to: fileURL)

            logger
                .debug("SAVED \(String(data: jsonData, encoding: .utf8) ?? "", privacy: .public)")
        } catch {
            logger.error("An error occurred while saving the file: \(error, privacy: .public)")
        }
    }

    func add(translation response: TranslationSession.Response) {
        if let identifier = response.targetLanguage.languageCode?.identifier {
            self.add(
                translation: response.targetText,
                forLanguage: identifier,
                original: response.sourceText
            )
        }
    }

    func add(translation: String, forLanguage: String, original: String) {
        if var strings = languageDictionary["strings"] as? [String: Any],
           var item = strings[original] as? [String: Any] {
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
                //                if let stringValue = value as? String {
                //                    stringsToTranslate[key] = stringValue
                //                }
                guard let value = value as? [String: Any] else { continue }
                stringsToTranslate.append(key)
                shouldTranslate.append(value["shouldTranslate"] as? Bool ?? true)
            }
        }
    }

    var data: Data {
        try! JSONSerialization.data(
            // swiftlint:disable:previous force_try
            withJSONObject: languageDictionary,
            options: .prettyPrinted
        )
    }
}
