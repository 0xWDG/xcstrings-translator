//
//  XCSTRINGSTranslatorApp
//  xcstrings-translator
//
//  Created by Wesley de Groot on 31/01/2025.
//

import SwiftUI

@main
struct XCSTRINGSTranslatorApp: App {
    var body: some Scene {
        Window("xcstrings translator", id: "main") {
            ContentView()
                .toolbarBackground(.hidden, for: .windowToolbar)
                .containerBackground(.ultraThinMaterial, for: .window)
        }
    }
}
