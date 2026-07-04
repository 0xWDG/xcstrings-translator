//
//  LanguageParser+FormatSpecifiers.swift
//  XCStrings Translator
//
//  Created by Wesley de Groot on 27/06/2026.
//

import Foundation

/// Format-specifier preservation for translated strings.
///
/// Apple's Translation framework is optimized for natural language, not printf-style
/// placeholders. It may translate, duplicate, drop, or partially split tokens such as
/// `%lld`, `%1$@`, and `%0.2f`. These helpers repair the translated text so runtime
/// formatting calls still receive the placeholders expected by the source string.
extension LanguageParser {
    /// Preserves source printf-style format specifiers in translated text.
    ///
    /// - Parameters:
    ///   - translation: Translation framework output.
    ///   - original: Original catalog string used as the specifier source of truth.
    /// - Returns: Translation with compatible placeholder values restored where possible.
    ///
    /// Implementation Notes:
    /// The function first collapses repeated unit placeholders, then checks whether
    /// the translated and original specifier lists have matching counts and conversion
    /// categories. If they do, it replaces translated placeholder spelling with the
    /// exact original spelling. If they do not, it falls back to a repair pass that can
    /// remove malformed leading clusters and reinsert missing specifiers.
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
            return repairingMalformedFormatSpecifiers(
                in: preservedTranslation,
                matching: original,
                originalSpecifiers: originalSpecifiers
            )
        }

        guard zip(originalSpecifiers, translationSpecifiers).allSatisfy({
            $0.conversion == $1.conversion
        }) else {
            return repairingMalformedFormatSpecifiers(
                in: preservedTranslation,
                matching: original,
                originalSpecifiers: originalSpecifiers
            )
        }

        for (originalSpecifier, translationSpecifier) in zip(
            originalSpecifiers,
            translationSpecifiers
        ).reversed() where originalSpecifier.value != translationSpecifier.value {
            preservedTranslation.replaceSubrange(
                translationSpecifier.range,
                with: originalSpecifier.value
            )
        }

        return preservedTranslation
    }

    /// Repairs translations where placeholder parsing no longer matches the source.
    ///
    /// - Parameters:
    ///   - translation: Candidate translated text.
    ///   - original: Original source string. Included for symmetry with caller context.
    ///   - originalSpecifiers: Parsed source specifiers that must survive.
    /// - Returns: Best-effort repaired translation.
    ///
    /// Edge Cases:
    /// Translation can turn `%lld` into a cluster such as `%I %ll %ld %p%r`. The repair
    /// pass removes or replaces such clusters before matching remaining conversion
    /// categories from the end of the string, which tends to preserve sentence order.
    private func repairingMalformedFormatSpecifiers(
        in translation: String,
        matching original: String,
        originalSpecifiers: [FormatSpecifier]
    ) -> String {
        guard !originalSpecifiers.isEmpty else {
            return translation
        }

        var repairedTranslation = translation

        if let leadingClusterRange = leadingPercentClusterRange(in: repairedTranslation) {
            if originalSpecifiers.count == 1 {
                repairedTranslation.replaceSubrange(
                    leadingClusterRange,
                    with: originalSpecifiers[0].value
                )
            } else if formatSpecifiers(in: String(repairedTranslation[leadingClusterRange])).isEmpty {
                repairedTranslation.removeSubrange(leadingClusterRange)
            }
        }

        var matchedOriginalIndexes = Set<Int>()
        var matchedTranslationIndexes = Set<Int>()
        let translationSpecifiers = formatSpecifiers(in: repairedTranslation)
        var replacements: [(range: Range<String.Index>, value: String)] = []

        for originalIndex in originalSpecifiers.indices.reversed() {
            guard let translationIndex = translationSpecifiers.indices.reversed().first(where: {
                !matchedTranslationIndexes.contains($0) &&
                    translationSpecifiers[$0].conversion == originalSpecifiers[originalIndex].conversion
            }) else {
                continue
            }

            matchedOriginalIndexes.insert(originalIndex)
            matchedTranslationIndexes.insert(translationIndex)

            if translationSpecifiers[translationIndex].value != originalSpecifiers[originalIndex].value {
                replacements.append(
                    (
                        range: translationSpecifiers[translationIndex].range,
                        value: originalSpecifiers[originalIndex].value
                    )
                )
            }
        }

        for replacement in replacements.sorted(by: { $0.range.lowerBound > $1.range.lowerBound }) {
            repairedTranslation.replaceSubrange(replacement.range, with: replacement.value)
        }

        let missingSpecifiers = originalSpecifiers.indices
            .filter { !matchedOriginalIndexes.contains($0) }
            .map { originalSpecifiers[$0].value }

        for missingSpecifier in missingSpecifiers.reversed() {
            insertMissingFormatSpecifier(missingSpecifier, into: &repairedTranslation)
        }

        return repairedTranslation
    }

    /// Inserts a missing placeholder into a translation using a conservative position.
    ///
    /// - Parameters:
    ///   - specifier: Source placeholder that was dropped by translation.
    ///   - translation: Translation text to mutate.
    ///
    /// Rationale:
    /// When a comma exists, inserting before it often preserves phrases such as
    /// "Step %1$lld, %@". Otherwise the placeholder is prepended so runtime formatting
    /// remains valid even if the exact linguistic position is imperfect.
    private func insertMissingFormatSpecifier(
        _ specifier: String,
        into translation: inout String
    ) {
        if let commaIndex = translation.firstIndex(of: ",") {
            let needsLeadingSpace = commaIndex > translation.startIndex &&
                translation[translation.index(before: commaIndex)].isWhitespace == false
            translation.insert(contentsOf: "\(needsLeadingSpace ? " " : "")\(specifier)", at: commaIndex)
            return
        }

        if translation.isEmpty {
            translation = specifier
        } else {
            translation = "\(specifier) \(translation)"
        }
    }

    /// Finds a malformed or repeated leading cluster of percent fragments.
    ///
    /// - Parameter string: Translation text to inspect.
    /// - Returns: Range from the start of the string through the last leading percent
    ///   fragment, or `nil` when the string starts with normal text.
    private func leadingPercentClusterRange(in string: String) -> Range<String.Index>? {
        var index = string.startIndex
        var lastFragmentEnd: String.Index?

        while index < string.endIndex {
            if string[index].isWhitespace {
                index = string.index(after: index)
                continue
            }

            guard string[index] == "%" else {
                break
            }

            index = percentFragmentEnd(in: string, from: index)
            lastFragmentEnd = index
        }

        guard let lastFragmentEnd else {
            return nil
        }

        return string.startIndex..<lastFragmentEnd
    }

    /// Advances over one percent-led fragment.
    ///
    /// - Parameters:
    ///   - string: String containing a percent character at `start`.
    ///   - start: Index of `%`.
    /// - Returns: Index just after the parsed fragment.
    ///
    /// This accepts valid format specifiers, escaped percent signs, and partial pieces
    /// such as `%ll` so malformed leading clusters can still be removed safely.
    private func percentFragmentEnd(in string: String, from start: String.Index) -> String.Index {
        let index = string.index(after: start)

        guard index < string.endIndex else {
            return index
        }

        if string[index] == "%" {
            return string.index(after: index)
        }

        let parsedEnd = parsedFormatSpecifierEnd(in: string, from: start)
        if parsedEnd > start {
            return parsedEnd
        }

        if string[index] == "l" {
            let nextIndex = string.index(after: index)
            if nextIndex < string.endIndex, string[nextIndex] == "l" {
                return string.index(after: nextIndex)
            }
        }

        return string.index(after: index)
    }

    /// Parses the end index of a complete printf-style specifier.
    ///
    /// - Parameters:
    ///   - string: String containing `%` at `start`.
    ///   - start: Index of `%`.
    /// - Returns: End index after the conversion character, or `start` when parsing fails.
    private func parsedFormatSpecifierEnd(in string: String, from start: String.Index) -> String.Index {
        var index = string.index(after: start)

        parsePositionalArgument(in: string, from: &index)
        parseCharacters(in: string, from: &index, matching: "-+ #0'")
        parseWidthOrPrecision(in: string, from: &index)

        if index < string.endIndex, string[index] == "." {
            index = string.index(after: index)
            parseWidthOrPrecision(in: string, from: &index)
        }

        parseLengthModifier(in: string, from: &index)

        guard index < string.endIndex,
              FormatSpecifier.Conversion(character: string[index]) != nil else {
            return start
        }

        return string.index(after: index)
    }

    /// Collapses repeated placeholders that translation duplicated next to unit suffixes.
    ///
    /// - Parameters:
    ///   - translation: Candidate translated text.
    ///   - original: Source text that defines placeholder suffixes.
    ///   - originalSpecifiers: Parsed source placeholders.
    /// - Returns: Translation with repeated placeholder runs replaced by one source
    ///   placeholder plus its original suffix.
    ///
    /// Example:
    /// A source `%lldm` can be translated as `%ldm%ldm%ldm`. Collapsing the run before
    /// direct replacement keeps the final output at `%lldm`.
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

    /// Finds adjacent runs of placeholders with the same conversion and suffix.
    ///
    /// - Parameters:
    ///   - string: String being repaired.
    ///   - conversion: Placeholder conversion category to match.
    ///   - suffix: Alphabetic unit suffix that must follow each placeholder.
    ///   - specifiers: Parsed placeholders in `string`.
    /// - Returns: Ranges covering repeated runs that should collapse to one placeholder.
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

    /// Returns the end of a placeholder plus its expected suffix.
    ///
    /// - Parameters:
    ///   - string: String containing the placeholder.
    ///   - specifier: Parsed placeholder.
    ///   - suffix: Expected alphabetic unit suffix.
    /// - Returns: End index after the suffix, or `nil` when the suffix is not present.
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

    /// Reads the alphabetic suffix immediately after a source placeholder.
    ///
    /// - Parameters:
    ///   - string: Source string.
    ///   - index: Index immediately after a parsed placeholder.
    /// - Returns: Contiguous letters after the placeholder, such as `m` in `%lldm`.
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

    /// Parses printf-style placeholders from a string.
    ///
    /// - Parameter string: Text to scan.
    /// - Returns: Parsed placeholders with source ranges and conversion categories.
    ///
    /// The parser intentionally recognizes the subset used by Apple localized format
    /// strings rather than implementing a full C formatter. It supports positional
    /// arguments, flags, width, precision, length modifiers, and common conversion
    /// characters.
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

    /// Parses an optional positional argument such as `1$`.
    ///
    /// - Parameters:
    ///   - string: String being scanned.
    ///   - index: In-out cursor advanced only when a complete positional argument exists.
    private func parsePositionalArgument(in string: String, from index: inout String.Index) {
        let initialIndex = index
        parseDigits(in: string, from: &index)

        if index < string.endIndex, string[index] == "$" {
            index = string.index(after: index)
        } else {
            index = initialIndex
        }
    }

    /// Advances a scanner while the current character belongs to a given set.
    ///
    /// - Parameters:
    ///   - string: String being scanned.
    ///   - index: In-out cursor.
    ///   - characters: Allowed characters to consume.
    private func parseCharacters(
        in string: String,
        from index: inout String.Index,
        matching characters: String
    ) {
        while index < string.endIndex, characters.contains(string[index]) {
            index = string.index(after: index)
        }
    }

    /// Parses `*`, `*n$`, or decimal width/precision segments.
    ///
    /// - Parameters:
    ///   - string: String being scanned.
    ///   - index: In-out cursor.
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

    /// Parses a printf length modifier.
    ///
    /// - Parameters:
    ///   - string: String being scanned.
    ///   - index: In-out cursor.
    ///
    /// The `q` modifier is accepted because Apple format strings historically use it
    /// as a synonym for long long in Objective-C contexts.
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

    /// Advances over a contiguous run of decimal digits.
    ///
    /// - Parameters:
    ///   - string: String being scanned.
    ///   - index: In-out cursor.
    private func parseDigits(in string: String, from index: inout String.Index) {
        while index < string.endIndex, string[index].isNumber {
            index = string.index(after: index)
        }
    }
}

/// Parsed printf-style placeholder.
private struct FormatSpecifier {
    /// Placeholder conversion category.
    ///
    /// The exact conversion character may vary (`d`, `i`, `D`), but repair only needs
    /// categories that are interchangeable from a placeholder-preservation standpoint.
    enum Conversion: Equatable {
        case signedInteger
        case unsignedInteger
        case floatingPoint
        case object
        case character
        case string
        case pointer
        case count

        /// Creates a conversion category from a printf conversion character.
        ///
        /// - Parameter character: Final conversion character in a format specifier.
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

    /// Exact placeholder text, including `%`, flags, width, precision, length, and conversion.
    let value: String
    /// Range of `value` in the scanned string.
    let range: Range<String.Index>
    /// Coarse conversion category used for compatibility matching.
    let conversion: Conversion
}
// swiftlint:disable:this file_length
