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
    /// Content types this document can read when SwiftUI constructs it from a file.
    static var readableContentTypes: [UTType] {
        [.xcstrings]
    }

    /// Content types this document can write from the export panel.
    static var writableContentTypes: [UTType] {
        [.xcstrings]
    }

    /// Pre-encoded catalog bytes.
    let data: Data

    /// Creates a document from already encoded catalog data.
    ///
    /// - Parameter data: JSON bytes produced by `LanguageParser`.
    init(data: Data) {
        self.data = data
    }

    /// Creates a document from SwiftUI read configuration.
    ///
    /// - Parameter configuration: File contents supplied by SwiftUI.
    /// - Throws: This initializer currently does not throw; missing contents produce
    ///   empty data because this type is only used for export in the app workflow.
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    /// Provides the file wrapper SwiftUI writes to disk.
    ///
    /// - Parameter configuration: SwiftUI write configuration.
    /// - Returns: Regular file wrapper containing `data`.
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
