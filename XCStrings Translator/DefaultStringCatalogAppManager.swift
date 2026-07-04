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
    /// UserDefaults key that records whether the user has answered the default-app prompt.
    private static let promptResponseKey = "didRespondToDefaultStringCatalogAppPrompt"

    /// Whether the post-translation default-app prompt has already been answered.
    ///
    /// Side Effects:
    /// Setting this property persists the response in `UserDefaults`.
    static var didRespondToPrompt: Bool {
        get {
            UserDefaults.standard.bool(forKey: promptResponseKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: promptResponseKey)
        }
    }

    /// Whether Launch Services currently routes `.xcstrings` files to this app.
    ///
    /// Thread Safety:
    /// Main-actor isolated because it is consumed by SwiftUI workflow code and reads
    /// process bundle state.
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

    /// Whether the app should ask the user to become the default `.xcstrings` opener.
    @MainActor
    static var shouldPromptAfterTranslation: Bool {
        !didRespondToPrompt && !isCurrentAppDefault
    }

    /// Registers this app as the default handler for `.xcstrings` files.
    ///
    /// - Parameter completion: Main-actor callback receiving success or the system error.
    ///
    /// Side Effects:
    /// Calls `NSWorkspace.setDefaultApplication`, may change Launch Services
    /// registration, and records prompt completion on success.
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
