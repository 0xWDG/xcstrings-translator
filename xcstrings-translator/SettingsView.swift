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
        ], _acknowledgements: []) {
            Section {
                Picker(selection: $languageParser.state, content: {
                    ForEach(LanguageParser.LPState.allCases, id: \.rawValue) { state in
                        Text(state.humanReadableName)
                            .tag(state)
                    }
                }, label: {
                    Text("Translation state")
                    Text("This is the state which is saved in the strings file.")
                        .font(.caption)
                })
                .pickerStyle(.segmented)

                Toggle(isOn: $languageParser.isTesting) {
                    Text("Test Mode")
                    Text("Does not overwrite the original strings file.")
                        .font(.caption)
                }
                .toggleStyle(.switch)
            } header: {
                Label("Settings", systemImage: "gear")
            }
        } bottomContent: {

        }
        .toolbar {
            Button("Close") {
                dismiss()
            }
        }
        .frame(minWidth: 500, minHeight: 500)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(LanguageParser())
    }
}
