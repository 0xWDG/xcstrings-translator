//
//  LanguageParser.swift
//  xcstrings-translator
//
//  Created by Wesley de Groot on 31/01/2025.
//

import Foundation
import OSLog
import Translation

struct LanguageItem: Codable {
    var base: String

    // ISO Languages
    // swiftlint:disable identifier_name
    var nl: String
    var en: String
    var fr: String
    var de: String
    // swiftlint:enable identifier_name
}

class LanguageParser: ObservableObject {
    private let logger = Logger(
        subsystem: "nl.wesleydegroot.xcstrings-translator",
        category: "LanguageParser"
    )

    @Published var languageDictionary: [String: Any] = [:]
    @Published var stringsToTranslate: [String] = []
    @Published var shouldTranslate: [Bool] = []
    @Published var sourceLanguage: String = "en"
    @Published var fileURL: URL?
    private var isTesting = true

    func load(file url: URL) {
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

    // TODO: This actually does not mutate the languageDictionary.
    // Also saving `languageDictionary["strings"] = strings` does not make any difference
    func add(translation: String, forLanguage: String, original: String) {
        if var strings = languageDictionary["strings"] as? [String: Any],
           var item = strings[original] as? [String: Any] {
            // { "strings": { "string": { shouldtranslate: false?
            // "localizations" : { "nl" : { "stringUnit" : { "state" : "translated", "value" : "%@"

            if var localizations = item["localizations"] as? [String: Any] {
                print(
                    "Updated \(forLanguage) with \(original) with \(translation)"
                )
                localizations[forLanguage] = ["stringUnit": ["state": "needs_review", "value": translation]]
                languageDictionary["strings"] = strings
                return
            } else {
                print(
                    "Created localizations: \(forLanguage) for \(original) with \(translation)"
                )
                item["localizations"] = [forLanguage: ["stringUnit": ["state": "needs_review", "value": translation]]]
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
}
