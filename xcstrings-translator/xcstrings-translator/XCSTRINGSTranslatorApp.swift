//
//  XCSTRINGSTranslatorApp
//  xcstrings-translator
//
//  Created by Wesley de Groot on 31/01/2025.
//

import SwiftUI

@main
struct XCSTRINGSTranslatorApp: App {
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup {
            ContentView()
                .toolbarBackground(.hidden, for: .windowToolbar)
                .containerBackground(.ultraThinMaterial, for: .window)
        }
    }
}
