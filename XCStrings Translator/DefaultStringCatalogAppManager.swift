//
//  DefaultStringCatalogAppManager.swift
//  XCStrings Translator
//
//  Created by Wesley de Groot on 21/06/2026.
//

import AppKit
import CoreServices
import Foundation
import UniformTypeIdentifiers

/// Handles Finder/Open With registration for `.xcstrings` files.
///
/// Launch Services owns the default-app relationship, so this small wrapper keeps
/// those AppKit/CoreServices calls out of the SwiftUI views.
enum DefaultStringCatalogAppManager {
    private static let promptResponseKey = "didRespondToDefaultStringCatalogAppPrompt"

    static var didRespondToPrompt: Bool {
        get {
            UserDefaults.standard.bool(forKey: promptResponseKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: promptResponseKey)
        }
    }

    @MainActor
    static var isCurrentAppDefault: Bool {
        // LSCopyDefaultRoleHandlerForContentType returns the bundle identifier of the
        // app currently registered to open this UTI.
        guard let bundleIdentifier = Bundle.main.bundleIdentifier,
              let defaultHandler = LSCopyDefaultRoleHandlerForContentType(
                UTType.xcstrings.identifier as CFString,
                .all
              )?.takeRetainedValue() as String? else {
            return false
        }

        return defaultHandler == bundleIdentifier
    }

    @MainActor
    static var shouldPromptAfterTranslation: Bool {
        !didRespondToPrompt && !isCurrentAppDefault
    }

    static func setAsDefault(
        completion: @escaping @MainActor (Result<Void, Error>) -> Void
    ) {
        // NSWorkspace performs the actual registration and may prompt or fail based on
        // system policy, so callers receive an async result for UI feedback.
        NSWorkspace.shared.setDefaultApplication(
            at: Bundle.main.bundleURL,
            toOpen: .xcstrings
        ) { error in
            Task { @MainActor in
                if let error {
                    completion(.failure(error))
                } else {
                    didRespondToPrompt = true
                    completion(.success(()))
                }
            }
        }
    }
}
