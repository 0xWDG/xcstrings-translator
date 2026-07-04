//
//  XCStringsTranslatorApp
//  XCStrings Translator
//
//  Created by Wesley de Groot on 31/01/2025.
//

import SwiftUI

/// Application entry point for XCStrings Translator.
///
/// The app creates a single main window containing `ContentView`. All catalog state
/// and translation workflow coordination lives below that view; this type only defines
/// scene setup and window-level styling.
@main
struct XCStringsTranslatorApp: App {
    /// Main app scene.
    var body: some Scene {
        Window("XCStrings translator", id: "main") {
            ContentView()
                .toolbarBackground(.hidden, for: .windowToolbar)
                .containerBackground(.ultraThinMaterial, for: .window)
        }
    }
}
