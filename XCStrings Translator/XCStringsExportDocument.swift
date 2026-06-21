//
//  XCStringsExportDocument.swift
//  XCStrings Translator
//
//  Created by Wesley de Groot on 21/06/2026.
//

import SwiftUI
import UniformTypeIdentifiers

/// Minimal FileDocument wrapper used by SwiftUI's fileExporter.
///
/// The parser owns the catalog structure. This document only hands the already encoded
/// bytes to the system save panel while preserving the `.xcstrings` content type.
struct XCStringsExportDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.xcstrings]
    }

    static var writableContentTypes: [UTType] {
        [.xcstrings]
    }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
