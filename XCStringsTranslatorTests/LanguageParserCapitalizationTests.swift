//
//  LanguageParserCapitalizationTests.swift
//  XCStrings TranslatorTests
//
//  Created by Wesley de Groot on 21/06/2026.
//

import Foundation
import Testing
@testable import XCStrings_Translator

@MainActor
struct LanguageParserCapitalizationTests {
    @Test func addingTranslationUppercasesFirstCharacterWhenSourceStartsUppercase() async throws {
        let parser = parserWithString("Hello")

        parser.add(
            translation: "hallo",
            forLanguage: "nl",
            original: "Hello"
        )

        #expect(try translatedValue(in: parser, for: "Hello") == "Hallo")
    }

    @Test func addingTranslationKeepsCasingWhenSourceStartsLowercase() async throws {
        let parser = parserWithString("hello")

        parser.add(
            translation: "hallo",
            forLanguage: "nl",
            original: "hello"
        )

        #expect(try translatedValue(in: parser, for: "hello") == "hallo")
    }

    private func parserWithString(_ string: String) -> LanguageParser {
        let parser = LanguageParser()
        parser.languageDictionary = [
            "strings": [
                string: [
                    "localizations": [:]
                ]
            ]
        ]
        return parser
    }

    private func translatedValue(
        in parser: LanguageParser,
        for string: String
    ) throws -> String? {
        let strings = try #require(parser.languageDictionary["strings"] as? [String: Any])
        let item = try #require(strings[string] as? [String: Any])
        let localizations = try #require(item["localizations"] as? [String: Any])
        let localization = try #require(localizations["nl"] as? [String: Any])
        let stringUnit = try #require(localization["stringUnit"] as? [String: Any])
        return stringUnit["value"] as? String
    }
}
