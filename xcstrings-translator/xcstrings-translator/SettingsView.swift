//
//  SettingsView.swift
//  xcstrings-translator
//
//  Created by Wesley de Groot on 09/02/2025.
//

import SwiftUI
import OSLogViewer
import StoreKit
import SwiftExtras


struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var languageParser: LanguageParser

    var body: some View {
        SESettingsView(_changeLog: [
            .init(version: "0.0.1", text: "Initial release")
        ]) {
            Section("Settings") {
                Picker("Translation state", selection: $languageParser.state) {
                    ForEach(LanguageParser.LPState.allCases, id: \.rawValue) { state in
                        Text(state.humanReadableName)
                            .tag(state)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(LanguageParser())
}
