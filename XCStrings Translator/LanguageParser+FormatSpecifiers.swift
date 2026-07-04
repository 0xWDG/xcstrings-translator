//
//  LanguageParser+FormatSpecifiers.swift
//  XCStrings Translator
//
//  Created by Wesley de Groot on 27/06/2026.
//

import Foundation

extension LanguageParser {
    func preservingFormatSpecifiers(
        in translation: String,
        matching original: String
    ) -> String {
        let originalSpecifiers = formatSpecifiers(in: original)
        let translationSpecifiers = formatSpecifiers(in: translation)

        guard originalSpecifiers.count == translationSpecifiers.count else {
            return translation
        }

        var preservedTranslation = translation
        for (originalSpecifier, translationSpecifier) in zip(
            originalSpecifiers,
            translationSpecifiers
        ).reversed() where originalSpecifier.conversion == translationSpecifier.conversion
            && originalSpecifier.value != translationSpecifier.value {
            preservedTranslation.replaceSubrange(
                translationSpecifier.range,
                with: originalSpecifier.value
            )
        }

        return preservedTranslation
    }

    private func formatSpecifiers(in string: String) -> [FormatSpecifier] {
        var specifiers: [FormatSpecifier] = []
        var index = string.startIndex

        while index < string.endIndex {
            guard string[index] == "%" else {
                index = string.index(after: index)
                continue
            }

            let start = index
            index = string.index(after: index)

            guard index < string.endIndex else {
                break
            }

            if string[index] == "%" {
                index = string.index(after: index)
                continue
            }

            parsePositionalArgument(in: string, from: &index)
            parseCharacters(in: string, from: &index, matching: "-+ #0'")
            parseWidthOrPrecision(in: string, from: &index)

            if index < string.endIndex, string[index] == "." {
                index = string.index(after: index)
                parseWidthOrPrecision(in: string, from: &index)
            }

            parseLengthModifier(in: string, from: &index)

            guard index < string.endIndex,
                  let conversion = FormatSpecifier.Conversion(character: string[index]) else {
                index = string.index(after: start)
                continue
            }

            let end = string.index(after: index)
            specifiers.append(
                FormatSpecifier(
                    value: String(string[start..<end]),
                    range: start..<end,
                    conversion: conversion
                )
            )
            index = end
        }

        return specifiers
    }

    private func parsePositionalArgument(in string: String, from index: inout String.Index) {
        let initialIndex = index
        parseDigits(in: string, from: &index)

        if index < string.endIndex, string[index] == "$" {
            index = string.index(after: index)
        } else {
            index = initialIndex
        }
    }

    private func parseCharacters(
        in string: String,
        from index: inout String.Index,
        matching characters: String
    ) {
        while index < string.endIndex, characters.contains(string[index]) {
            index = string.index(after: index)
        }
    }

    private func parseWidthOrPrecision(in string: String, from index: inout String.Index) {
        guard index < string.endIndex else {
            return
        }

        if string[index] == "*" {
            index = string.index(after: index)
            parsePositionalArgument(in: string, from: &index)
        } else {
            parseDigits(in: string, from: &index)
        }
    }

    private func parseLengthModifier(in string: String, from index: inout String.Index) {
        let twoCharacterModifiers = ["hh", "ll"]
        let oneCharacterModifiers: Set<Character> = ["h", "l", "j", "z", "t", "L", "q"]

        if let nextIndex = string.index(index, offsetBy: 1, limitedBy: string.endIndex),
           nextIndex < string.endIndex,
           twoCharacterModifiers.contains(String(string[index...nextIndex])) {
            index = string.index(after: nextIndex)
        } else if index < string.endIndex, oneCharacterModifiers.contains(string[index]) {
            index = string.index(after: index)
        }
    }

    private func parseDigits(in string: String, from index: inout String.Index) {
        while index < string.endIndex, string[index].isNumber {
            index = string.index(after: index)
        }
    }
}

private struct FormatSpecifier {
    enum Conversion: Equatable {
        case signedInteger
        case unsignedInteger
        case floatingPoint
        case object
        case character
        case string
        case pointer
        case count

        init?(character: Character) {
            switch character {
            case "d", "D", "i":
                self = .signedInteger
            case "u", "U", "x", "X", "o", "O":
                self = .unsignedInteger
            case "f", "F", "e", "E", "g", "G", "a", "A":
                self = .floatingPoint
            case "@":
                self = .object
            case "c", "C":
                self = .character
            case "s", "S":
                self = .string
            case "p":
                self = .pointer
            case "n":
                self = .count
            default:
                return nil
            }
        }
    }

    let value: String
    let range: Range<String.Index>
    let conversion: Conversion
}
