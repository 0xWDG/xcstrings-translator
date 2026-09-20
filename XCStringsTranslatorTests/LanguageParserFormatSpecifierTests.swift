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

    @Test func addingTranslationRemovesUnexpectedFormatSpecifier() async throws {
        let parser = parserWithString("%1$@, %2$lld items")

        parser.add(
            translation: "%A %@, %lld-elementer",
            forLanguage: "da",
            original: "%1$@, %2$lld items"
        )

        #expect(
            try translatedValue(
                in: parser,
                for: "%1$@, %2$lld items",
                language: "da"
            ) == "%1$@, %2$lld-elementer"
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

    @Test func addingTranslationRepairsExplodedLongLongSpecifier() async throws {
        let parser = parserWithString("%lld")

        parser.add(
            translation: "%ld%n%r%n%j",
            forLanguage: "nl",
            original: "%lld"
        )

        #expect(try translatedValue(in: parser, for: "%lld") == "%lld")
    }

    @Test func addingTranslationRepairsMalformedLeadingSpecifierCluster() async throws {
        let parser = parserWithString("%lld percent")

        parser.add(
            translation: "%I %ll %ld %p%r ciento",
            forLanguage: "es",
            original: "%lld percent"
        )

        #expect(try translatedValue(in: parser, for: "%lld percent", language: "es") == "%lld ciento")
    }

    @Test func addingTranslationRestoresDroppedPositionalSpecifier() async throws {
        let parser = parserWithString("Step %1$lld, %2$@")

        parser.add(
            translation: "%IÉtape, %@",
            forLanguage: "fr",
            original: "Step %1$lld, %2$@"
        )

        #expect(
            try translatedValue(
                in: parser,
                for: "Step %1$lld, %2$@",
                language: "fr"
            ) == "Étape %1$lld, %2$@"
        )
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
        for string: String,
        language: String = "nl"
    ) throws -> String? {
        let strings = try #require(parser.languageDictionary["strings"] as? [String: Any])
        let item = try #require(strings[string] as? [String: Any])
        let localizations = try #require(item["localizations"] as? [String: Any])
        let localization = try #require(localizations[language] as? [String: Any])
        let stringUnit = try #require(localization["stringUnit"] as? [String: Any])
        return stringUnit["value"] as? String
    }
}
