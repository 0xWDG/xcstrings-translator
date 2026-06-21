//
//  XCStringsFileType.swift
//  XCStrings Translator
//
//  Created by Wesley de Groot on 21/06/2026.
//

import UniformTypeIdentifiers

extension UTType {
    // Xcode string catalogs are JSON files with a custom UTI. Declaring the type lets
    // file pickers/exporters advertise `.xcstrings` instead of generic JSON.
    static let xcstrings = UTType(
        importedAs: "com.apple.xcode.xcstrings",
        conformingTo: .json
    )
}
