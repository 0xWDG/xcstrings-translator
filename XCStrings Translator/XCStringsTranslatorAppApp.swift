//
//  XCStringsTranslatorApp
//  XCStrings Translator
//
//  Created by Wesley de Groot on 31/01/2025.
//

import SwiftUI

@main
struct XCStringsTranslatorApp: App {
    var body: some Scene {
        Window("XCStrings translator", id: "main") {
            ContentView()
                .toolbarBackground(.hidden, for: .windowToolbar)
                .containerBackground(.ultraThinMaterial, for: .window)
        }
    }
}
