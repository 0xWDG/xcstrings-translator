//
//  LanguageParser.swift
//  xcstrings-translator
//
//  Created by Wesley de Groot on 31/01/2025.
//

import Foundation
import OSLog

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

            if isTesting {
                logger.debug("We are testing, appending _test.json to the filename")
                fileURL = fileURL.appending(component: "_test.json")
            }

            try jsonData.write(to: fileURL)

            logger
                .debug("SAVED \(String(data: jsonData, encoding: .utf8) ?? "", privacy: .public)")
        } catch {
            logger.error("An error occurred while saving the file: \(error, privacy: .public)")
        }
    }

    func parse() {
        stringsToTranslate = []

        if let strings = languageDictionary["strings"] as? [String: Any] {
            for (key, value) in strings {
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
