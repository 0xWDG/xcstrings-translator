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
        var preservedTranslation = collapsingRepeatedFormatSpecifiers(
            in: translation,
            matching: original,
            originalSpecifiers: originalSpecifiers
        )
        let translationSpecifiers = formatSpecifiers(in: preservedTranslation)

        guard originalSpecifiers.count == translationSpecifiers.count else {
            return preservedTranslation
        }

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

    private func collapsingRepeatedFormatSpecifiers(
        in translation: String,
        matching original: String,
        originalSpecifiers: [FormatSpecifier]
    ) -> String {
        var collapsedTranslation = translation

        for originalSpecifier in originalSpecifiers.reversed() {
            let originalSuffix = formatSpecifierSuffix(
                in: original,
                after: originalSpecifier.range.upperBound
            )
            let translationSpecifiers = formatSpecifiers(in: collapsedTranslation)
            let runs = repeatedFormatSpecifierRuns(
                in: collapsedTranslation,
                matching: originalSpecifier.conversion,
                suffix: originalSuffix,
                specifiers: translationSpecifiers
            )

            for run in runs.reversed() {
                collapsedTranslation.replaceSubrange(
                    run,
                    with: originalSpecifier.value + originalSuffix
                )
            }
        }

        return collapsedTranslation
    }

    private func repeatedFormatSpecifierRuns(
        in string: String,
        matching conversion: FormatSpecifier.Conversion,
        suffix: String,
        specifiers: [FormatSpecifier]
    ) -> [Range<String.Index>] {
        var runs: [Range<String.Index>] = []
        var currentRunStart: String.Index?
        var previousEnd: String.Index?
        var currentRunCount = 0

        for specifier in specifiers where specifier.conversion == conversion {
            let end = formatSpecifierEnd(
                in: string,
                for: specifier,
                suffix: suffix
            )

            guard let end else {
                if currentRunCount > 1,
                   let currentRunStart,
                   let previousEnd {
                    runs.append(currentRunStart..<previousEnd)
                }
                currentRunStart = nil
                previousEnd = nil
                currentRunCount = 0
                continue
            }

            if previousEnd == specifier.range.lowerBound {
                currentRunCount += 1
                previousEnd = end
            } else {
                if currentRunCount > 1,
                   let currentRunStart,
                   let previousEnd {
                    runs.append(currentRunStart..<previousEnd)
                }

                currentRunStart = specifier.range.lowerBound
                previousEnd = end
                currentRunCount = 1
            }
        }

        if currentRunCount > 1,
           let currentRunStart,
           let previousEnd {
            runs.append(currentRunStart..<previousEnd)
        }

        return runs
    }

    private func formatSpecifierEnd(
        in string: String,
        for specifier: FormatSpecifier,
        suffix: String
    ) -> String.Index? {
        let end = string.index(
            specifier.range.upperBound,
            offsetBy: suffix.count,
            limitedBy: string.endIndex
        )

        guard let end,
              String(string[specifier.range.upperBound..<end]) == suffix else {
            return nil
        }

        return end
    }

    private func formatSpecifierSuffix(
        in string: String,
        after index: String.Index
    ) -> String {
        var suffixEnd = index

        while suffixEnd < string.endIndex,
              string[suffixEnd].isLetter {
            suffixEnd = string.index(after: suffixEnd)
        }

        return String(string[index..<suffixEnd])
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
