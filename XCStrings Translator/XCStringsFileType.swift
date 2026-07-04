//
//  XCStringsFileType.swift
//  XCStrings Translator
//
//  Created by Wesley de Groot on 21/06/2026.
//

import UniformTypeIdentifiers

/// Uniform Type Identifier declarations used by file import and export flows.
extension UTType {
    /// Xcode String Catalog file type.
    ///
    /// Declaring the type lets file pickers/exporters advertise `.xcstrings` instead
    /// of generic JSON while still allowing standard JSON tooling to read the file.
    static let xcstrings = UTType(
        importedAs: "com.apple.xcode.xcstrings",
        conformingTo: .json
    )
}
