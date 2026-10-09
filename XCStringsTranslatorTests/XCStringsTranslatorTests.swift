//
//  xcstrings_translatorTests.swift
//  XCStrings TranslatorTests
//
//  Created by Wesley de Groot on 31/01/2025.
//

import Foundation
import Testing
@testable import XCStrings_Translator

@MainActor
struct XCStringsTranslatorTests {
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

    @Test func mainLanguageTargetsCollapseAllVariants() async throws {
        let targets = TranslationTargetsResolver.targets(
            for: .allAvailable,
            sourceLanguage: Locale.Language(identifier: "en"),
            supportedLanguages: [
                Locale.Language(identifier: "nl-BE"),
                Locale.Language(identifier: "nl-NL"),
                Locale.Language(identifier: "fr-CA"),
                Locale.Language(identifier: "fr-FR"),
                Locale.Language(identifier: "zh-Hant"),
                Locale.Language(identifier: "zh-Hans"),
                Locale.Language(identifier: "uk-UA")
            ],
            mainLanguagesOnly: true
        )

        #expect(targets.count == 5)
        #expect(
            targets.map(\.maximalIdentifier) == [
                "nl-Latn-NL",
                "fr-Latn-FR",
                "zh-Hant-TW",
                "zh-Hans-CN",
                "uk-Cyrl-UA"
            ]
        )
        #expect(
            targets.map {
                TranslationTargetsResolver.mainLanguageIdentifier(for: $0)
            } == ["nl", "fr", "zh", "zh", "uk"]
        )
        #expect(
            TranslationTargetsResolver.targetLanguageIdentifier(
                for: Locale.Language(identifier: "fr-FR"),
                mainLanguagesOnly: true,
                availableLanguages: targets
            ) == "fr"
        )
        #expect(
            TranslationTargetsResolver.targetLanguageIdentifier(
                for: Locale.Language(identifier: "uk-UA"),
                mainLanguagesOnly: true,
                availableLanguages: targets
            ) == "uk-UA"
        )
        #expect(
            TranslationTargetsResolver.targetLanguageIdentifier(
                for: Locale.Language(identifier: "zh-Hant"),
                mainLanguagesOnly: true,
                availableLanguages: targets
            ) == "zh-Hant"
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

    @Test func languageIdentifierPrefersLanguageOnlyForDutchAndItalian() async throws {
        #expect(
            TranslationTargetsResolver.languageIdentifier(
                for: Locale.Language(identifier: "nl-NL")
            ) == "nl"
        )
        #expect(
            TranslationTargetsResolver.languageIdentifier(
                for: Locale.Language(identifier: "nl-nl")
            ) == "nl"
        )
        #expect(
            TranslationTargetsResolver.languageIdentifier(
                for: Locale.Language(identifier: "it-IT")
            ) == "it"
        )
        #expect(
            TranslationTargetsResolver.languageIdentifier(
                for: Locale.Language(identifier: "it-it")
            ) == "it"
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

    @Test func systemLanguageDisplayPreservesExactIdentifier() async throws {
        let language = Locale.Language(identifier: "pt-BR")

        #expect(language.systemDisplayIdentifier == "pt-BR")
        #expect(language.localizedDisplayName(in: Locale(identifier: "en")) == "Portuguese (Brazil)")
    }

    @Test func defaultSourceLanguagePrefersEnglishUnitedStates() async throws {
        let defaultSourceLanguage = ContentView().preferredDefaultSourceLanguage(
            in: [
                Locale.Language(identifier: "en"),
                Locale.Language(identifier: "nl"),
                Locale.Language(identifier: "en-US")
            ]
        )

        #expect(defaultSourceLanguage?.matchesLanguageIdentifier("en-US") == true)
    }

    @Test func defaultSourceLanguageFallsBackToGenericEnglish() async throws {
        let defaultSourceLanguage = ContentView().preferredDefaultSourceLanguage(
            in: [
                Locale.Language(identifier: "nl"),
                Locale.Language(identifier: "en")
            ]
        )

        #expect(defaultSourceLanguage?.languageCode?.identifier == "en")
    }
}

@MainActor
struct LanguageParserTests {
    // swiftlint:disable:previous type_body_length
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

    @Test func addingTranslationPreservesExistingLocalizationMetadata() async throws {
        let parser = LanguageParser()
        parser.languageDictionary = [
            "strings": [
                "Files": [
                    "localizations": [
                        "nl": [
                            "variations": [
                                "plural": [
                                    "one": [
                                        "stringUnit": [
                                            "state": "translated",
                                            "value": "bestand"
                                        ]
                                    ]
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        ]

        parser.add(
            translation: "Bestanden",
            forLanguage: "nl",
            original: "Files"
        )

        let strings = try #require(parser.languageDictionary["strings"] as? [String: Any])
        let item = try #require(strings["Files"] as? [String: Any])
        let localizations = try #require(item["localizations"] as? [String: Any])
        let localization = try #require(localizations["nl"] as? [String: Any])
        let stringUnit = try #require(localization["stringUnit"] as? [String: Any])

        #expect(localization["variations"] != nil)
        #expect(stringUnit["value"] as? String == "Bestanden")
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

    @Test func parserRemovesOnlyEntriesMarkedStale() async throws {
        let parser = LanguageParser()
        parser.languageDictionary = [
            "strings": [
                "Old key": [
                    "extractionState": "stale",
                    "localizations": ["nl": ["stringUnit": ["value": "Oud"]]]
                ],
                "Active key": [
                    "localizations": ["nl": ["stringUnit": ["value": "Actief"]]]
                ]
            ]
        ]
        parser.parse()

        #expect(parser.removeStaleEntries() == 1)
        #expect(parser.removedStaleTranslationsCount == 1)

        let strings = try #require(parser.languageDictionary["strings"] as? [String: Any])
        #expect(strings["Old key"] == nil)
        #expect(strings["Active key"] != nil)
        #expect(parser.stringsToTranslate == ["Active key"])
    }

    @Test func parserUsesSourceLanguageValueForSemanticCatalogKeys() async throws {
        let parser = LanguageParser()
        parser.languageDictionary = [
            "sourceLanguage": "en",
            "strings": [
                "button.ok": [
                    "localizations": [
                        "en": [
                            "stringUnit": [
                                "state": "translated",
                                "value": "Ok"
                            ]
                        ]
                    ]
                ]
            ]
        ]
        parser.parse()

        #expect(parser.sourceText(for: "button.ok") == "Ok")

        parser.add(
            translation: "D'accord",
            forLanguage: "fr",
            original: "button.ok",
            source: parser.sourceText(for: "button.ok")
        )

        let strings = try #require(parser.languageDictionary["strings"] as? [String: Any])
        let item = try #require(strings["button.ok"] as? [String: Any])
        let localizations = try #require(item["localizations"] as? [String: Any])
        let frenchLocalization = try #require(localizations["fr"] as? [String: Any])
        let stringUnit = try #require(frenchLocalization["stringUnit"] as? [String: Any])

        #expect(stringUnit["value"] as? String == "D'accord")
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

    @Test func parserRecognizesExistingLanguagesWithEmptyTranslations() async throws {
        let parser = LanguageParser()
        parser.languageDictionary = [
            "strings": [
                "Hello": [
                    "localizations": [
                        "nl-NL": [
                            "stringUnit": [
                                "state": "new",
                                "value": ""
                            ]
                        ]
                    ]
                ]
            ]
        ]
        parser.parse()

        #expect(parser.hasExistingLocalization(forLanguage: "nl"))
        #expect(!parser.hasExistingLocalization(forLanguage: "de"))
    }

    @Test func stringsToTranslateTreatsRegionalVariantsAsOneMainLanguage() async throws {
        let parser = LanguageParser()
        parser.languageDictionary = [
            "strings": [
                "Hello": [
                    "localizations": [
                        "nl-BE": [
                            "stringUnit": [
                                "state": "translated",
                                "value": "Hallo"
                            ]
                        ]
                    ]
                ]
            ]
        ]
        parser.parse()

        #expect(
            parser.stringsToTranslate(
                forLanguage: "nl",
                skippingTranslated: true,
                treatingVariantsAsSameLanguage: true
            ).isEmpty
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
        parser.languageDictionary = try catalog(from: """
        {
          "strings": {
            "%lld files": {
              "localizations": {
                "nl": {
                  "variations": {
                    "plural": {
                      "one": { "stringUnit": { "state": "translated", "value": "%lld bestand" } },
                      "other": { "stringUnit": { "state": "translated", "value": "%lld bestanden" } }
                    }
                  }
                }
              }
            },
            "%lld folders": {
              "localizations": {
                "nl": {
                  "variations": {
                    "plural": {
                      "one": { "stringUnit": { "state": "translated", "value": "%lld map" } },
                      "other": { "stringUnit": { "state": "translated", "value": "" } }
                    }
                  }
                }
              }
            }
          }
        }
        """)
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

    private func catalog(from json: String) throws -> [String: Any] {
        let data = Data(json.utf8)
        return try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
    }
}
// swiftlint:disable:this file_length
