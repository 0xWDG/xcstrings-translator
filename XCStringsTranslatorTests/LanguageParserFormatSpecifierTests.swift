//
//  LanguageParserFormatSpecifierTests.swift
//  XCStrings TranslatorTests
//
//  Created by Wesley de Groot on 27/06/2026.
//

import Foundation
import Testing
@testable import XCStrings_Translator

@MainActor
struct LanguageParserFormatSpecifierTests {
    @Test func addingTranslationPreservesLongLongFormatSpecifier() async throws {
        let parser = parserWithString("%lld files")

        parser.add(
            translation: "%ld bestanden",
            forLanguage: "nl",
            original: "%lld files"
        )

        #expect(try translatedValue(in: parser, for: "%lld files") == "%lld bestanden")
    }

    @Test func addingTranslationPreservesMultipleFormatSpecifiersByPosition() async throws {
        let parser = parserWithString("%@ has %lld files")

        parser.add(
            translation: "%@ heeft %ld bestanden",
            forLanguage: "nl",
            original: "%@ has %lld files"
        )

        #expect(
            try translatedValue(in: parser, for: "%@ has %lld files") == "%@ heeft %lld bestanden"
        )
    }

    @Test func addingTranslationCollapsesRepeatedUnitFormatSpecifier() async throws {
        let parser = parserWithString("%lldm")

        parser.add(
            translation: "%ldm%ldm%ldm%ldm",
            forLanguage: "nl",
            original: "%lldm"
        )

        #expect(try translatedValue(in: parser, for: "%lldm") == "%lldm")
    }

    @Test func addingTranslationCollapsesRepeatedUnitFormatSpecifiersBySuffix() async throws {
        let parser = parserWithString("%lldh %lldm")

        parser.add(
            translation: "%ldh%ldh %ldm%ldm%ldm%ldm",
            forLanguage: "nl",
            original: "%lldh %lldm"
        )

        #expect(try translatedValue(in: parser, for: "%lldh %lldm") == "%lldh %lldm")
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
