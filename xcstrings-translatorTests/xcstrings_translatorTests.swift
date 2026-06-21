//
//  xcstrings_translatorTests.swift
//  xcstrings-translatorTests
//
//  Created by Wesley de Groot on 31/01/2025.
//

import Foundation
import Testing
@testable import xcstrings_translator

struct XCSTRINGSTranslatorTests {
    @Test func allAvailableTargetsExcludeSourceLanguage() async throws {
        let supportedLanguages = [
            Locale.Language(identifier: "en"),
            Locale.Language(identifier: "nl"),
            Locale.Language(identifier: "de")
        ]

        let targets = TranslationTargetsResolver.targets(
            for: .allAvailable,
            sourceLanguage: Locale.Language(identifier: "en"),
            supportedLanguages: supportedLanguages
        )

        #expect(
            targets.map { TranslationTargetsResolver.languageIdentifier(for: $0) } == ["nl", "de"]
        )
    }

    @Test func allAvailableTargetsExcludeSourceLanguageVariants() async throws {
        let supportedLanguages = [
            Locale.Language(identifier: "en-IN"),
            Locale.Language(identifier: "en-CA"),
            Locale.Language(identifier: "nl")
        ]

        let targets = TranslationTargetsResolver.targets(
            for: .allAvailable,
            sourceLanguage: Locale.Language(identifier: "en-IN"),
            supportedLanguages: supportedLanguages
        )

        #expect(
            targets.map { TranslationTargetsResolver.languageIdentifier(for: $0) } == ["nl"]
        )
    }

    @Test func singleTargetSelectionPreservesChosenLanguage() async throws {
        let target = Locale.Language(identifier: "pt-BR")
        let targets = TranslationTargetsResolver.targets(
            for: .language(target),
            sourceLanguage: Locale.Language(identifier: "en"),
            supportedLanguages: [
                Locale.Language(identifier: "en"),
                target
            ]
        )

        #expect(
            targets.map { TranslationTargetsResolver.languageIdentifier(for: $0) } == ["pt-BR"]
        )
    }

    @Test func languageIdentifierPreservesChineseScriptIdentifiers() async throws {
        #expect(
            TranslationTargetsResolver.languageIdentifier(
                for: Locale.Language(identifier: "zh-Hant")
            ) == "zh-Hant"
        )
        #expect(
            TranslationTargetsResolver.languageIdentifier(
                for: Locale.Language(identifier: "zh-Hans")
            ) == "zh-Hans"
        )
    }

    @Test func languageListPrefersExactIdentifierMatches() async throws {
        let language = LanguageList().language(
            for: Locale.Language(identifier: "pt-BR")
        )

        #expect(language?.identifier == "pt-BR")
    }

    @Test func addingTranslationPreservesRegionalLanguageIdentifier() async throws {
        let parser = LanguageParser()
        let regionalIdentifier = try #require(
            TranslationTargetsResolver.languageIdentifier(
                for: Locale.Language(identifier: "pt-BR")
            )
        )

        parser.languageDictionary = [
            "strings": [
                "Hello": [
                    "localizations": [:]
                ]
            ]
        ]

        parser.add(
            translation: "Ola",
            forLanguage: regionalIdentifier,
            original: "Hello"
        )

        let strings = try #require(parser.languageDictionary["strings"] as? [String: Any])
        let item = try #require(strings["Hello"] as? [String: Any])
        let localizations = try #require(item["localizations"] as? [String: Any])

        #expect(localizations["pt-BR"] != nil)
        #expect(localizations["pt"] == nil)
    }

    @Test func parserExcludesStringsMarkedDoNotTranslate() async throws {
        let parser = LanguageParser()
        parser.languageDictionary = [
            "strings": [
                "Translate me": [
                    "shouldTranslate": true
                ],
                "Skip me": [
                    "shouldTranslate": false
                ]
            ]
        ]

        parser.parse()

        #expect(Set(parser.stringsToTranslate) == Set(["Translate me"]))
    }

    @Test func stringsToTranslateSkipsExistingTargetTranslations() async throws {
        let parser = LanguageParser()
        parser.languageDictionary = [
            "strings": [
                "Hello": [
                    "localizations": [
                        "nl": [
                            "stringUnit": [
                                "state": "translated",
                                "value": "Hallo"
                            ]
                        ]
                    ]
                ],
                "Goodbye": [
                    "localizations": [:]
                ]
            ]
        ]
        parser.parse()

        #expect(
            Set(
                parser.stringsToTranslate(
                    forLanguage: "nl",
                    skippingTranslated: true
                )
            ) == Set(["Goodbye"])
        )
        #expect(
            Set(
                parser.stringsToTranslate(
                    forLanguage: "nl",
                    skippingTranslated: false
                )
            ) == Set(["Hello", "Goodbye"])
        )
    }

    @Test func stringsToTranslateSkipsExistingChineseScriptTranslations() async throws {
        let parser = LanguageParser()
        parser.languageDictionary = [
            "strings": [
                "Hello": [
                    "localizations": [
                        "zh-Hant": [
                            "stringUnit": [
                                "state": "translated",
                                "value": "你好"
                            ]
                        ]
                    ]
                ]
            ]
        ]
        parser.parse()

        let languageIdentifier = try #require(
            TranslationTargetsResolver.languageIdentifier(
                for: Locale.Language(identifier: "zh-Hant")
            )
        )

        #expect(
            parser.stringsToTranslate(
                forLanguage: languageIdentifier,
                skippingTranslated: true
            ).isEmpty
        )
    }

    @Test func stringsToTranslateSkipsTranslatedVariationUnits() async throws {
        let parser = LanguageParser()
        parser.languageDictionary = [
            "strings": [
                "%lld files": [
                    "localizations": [
                        "nl": [
                            "variations": [
                                "plural": [
                                    "one": [
                                        "stringUnit": [
                                            "state": "translated",
                                            "value": "%lld bestand"
                                        ]
                                    ],
                                    "other": [
                                        "stringUnit": [
                                            "state": "translated",
                                            "value": "%lld bestanden"
                                        ]
                                    ]
                                ]
                            ]
                        ]
                    ]
                ],
                "%lld folders": [
                    "localizations": [
                        "nl": [
                            "variations": [
                                "plural": [
                                    "one": [
                                        "stringUnit": [
                                            "state": "translated",
                                            "value": "%lld map"
                                        ]
                                    ],
                                    "other": [
                                        "stringUnit": [
                                            "state": "translated",
                                            "value": ""
                                        ]
                                    ]
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        ]
        parser.parse()

        #expect(
            Set(
                parser.stringsToTranslate(
                    forLanguage: "nl",
                    skippingTranslated: true
                )
            ) == Set(["%lld folders"])
        )
    }

    @Test func saveToLoadedFileWritesCurrentCatalog() async throws {
        let parser = LanguageParser()
        parser.isTesting = false
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("xcstrings")
        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        parser.fileURL = fileURL
        parser.languageDictionary = [
            "sourceLanguage": "en",
            "strings": [
                "Hello": [
                    "localizations": [
                        "nl": [
                            "stringUnit": [
                                "state": "translated",
                                "value": "Hallo"
                            ]
                        ]
                    ]
                ]
            ]
        ]

        let result = try parser.saveToLoadedFile()
        let savedData = try Data(contentsOf: fileURL)
        let savedCatalog = try #require(
            JSONSerialization.jsonObject(with: savedData) as? [String: Any]
        )

        #expect(result == .saved)
        #expect(savedCatalog["sourceLanguage"] as? String == "en")
    }

    @Test func saveToLoadedFileSkipsWhenTesting() async throws {
        let parser = LanguageParser()
        parser.isTesting = true
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("xcstrings")
        defer {
            parser.isTesting = false
            try? FileManager.default.removeItem(at: fileURL)
        }

        try Data("original".utf8).write(to: fileURL)
        parser.fileURL = fileURL
        parser.languageDictionary = [
            "strings": [:]
        ]

        let result = try parser.saveToLoadedFile()
        let savedContent = try String(contentsOf: fileURL, encoding: .utf8)

        #expect(result == .skippedTesting)
        #expect(savedContent == "original")
    }
}
