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

    let supportedLanguages: [Locale.Language]
    let languageName: (Locale.Language) -> String?

    var body: some View {
        SESettingsView(_changeLog: [
            .init(version: "0.0.1", text: "Initial release")
        ], _acknowledgements: [
            .init(
                name: "FilePicker",
                copyright: "Wesley de Groot",
                licence: "MIT",
                url: "https://github.com/0xWDG/FilePicker"
            )
        ]) {
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

                Picker(selection: $languageParser.defaultTargetLanguageIdentifier, content: {
                    Text("All Available Languages")
                        .tag(LanguageParser.allLanguagesDefaultTargetIdentifier)

                    ForEach(supportedLanguages, id: \.self) { language in
                        if let identifier = TranslationTargetsResolver.languageIdentifier(for: language) {
                            Text(languageName(language) ?? identifier)
                                .tag(identifier)
                        }
                    }
                }, label: {
                    Text("Default target language")
                    Text("Used as the selected target language when the app starts.")
                        .font(.caption)
                })

                Toggle(isOn: $languageParser.skipAlreadyTranslated) {
                    Text("Skip already translated")
                    Text("Only translate strings that do not already have a value for the target language.")
                        .font(.caption)
                }
                .toggleStyle(.switch)

                Toggle(isOn: $languageParser.autoSaveTranslations) {
                    Text("Automatically save")
                    Text("Save translations back to the opened string catalog when translation finishes.")
                        .font(.caption)
                }
                .toggleStyle(.switch)

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
        SettingsView(
            supportedLanguages: [
                Locale.Language(identifier: "nl")
            ],
            languageName: { language in
                TranslationTargetsResolver.languageIdentifier(
                    for: language
                )
            }
        )
            .environmentObject(LanguageParser())
    }
}
