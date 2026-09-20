//
//  SettingsView.swift
//  XCStrings Translator
//
//  Created by Wesley de Groot on 09/02/2025.
//

import OSLogViewer
import StoreKit
import SwiftExtras
import SwiftUI

/// Settings sheet for translation preferences and project metadata.
///
/// This view edits `LanguageParser`'s persisted preferences directly through an
/// environment object. The main workflow observes those published values and resets
/// run state when settings such as "skip already translated" or the default target
/// language change.
struct SettingsView: View {
    /// Dismiss action supplied by SwiftUI for the sheet.
    @Environment(\.dismiss) var dismiss
    /// Shared parser model that owns persisted settings.
    @EnvironmentObject var languageParser: LanguageParser
    /// Result text for the "Make Default App" action.
    @State private var defaultAppStatus: String?

    /// Languages that can be selected as the default target.
    let supportedLanguages: [Locale.Language]
    /// Display-name formatter supplied by `ContentView`.
    let languageName: (Locale.Language) -> String?

    /// Builds the settings form.
    ///
    /// Side Effects:
    /// Bindings write directly to `LanguageParser` properties, whose `didSet`
    /// observers persist values in `UserDefaults`.
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
                .accessibilityLabel("Translation state")
                .accessibilityHint("Choose the state saved for new translations in the string catalog.")
                .accessibilityIdentifier("translationStatePicker")

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
                .accessibilityLabel("Default target language")
                .accessibilityHint("Choose the target language selected when the app opens.")
                .accessibilityIdentifier("defaultTargetLanguagePicker")

                Toggle(isOn: $languageParser.skipAlreadyTranslated) {
                    Text("Skip already translated")
                    Text("Only translate strings that do not already have a value for the target language.")
                        .font(.caption)
                }
                .toggleStyle(.switch)
                .accessibilityLabel("Skip already translated")
                .accessibilityHint("When enabled, existing translations are not translated again.")
                .accessibilityIdentifier("skipAlreadyTranslatedToggle")

                Toggle(isOn: $languageParser.autoSaveTranslations) {
                    Text("Automatically save")
                    Text("Save progress after each completed language.")
                        .font(.caption)
                }
                .toggleStyle(.switch)
                .accessibilityLabel("Automatically save")
                .accessibilityHint("When enabled, completed language checkpoints are saved to the opened file.")
                .accessibilityIdentifier("autoSaveTranslationsToggle")

                Toggle(isOn: $languageParser.isTesting) {
                    Text("Test Mode")
                    Text("Does not overwrite the original strings file.")
                        .font(.caption)
                }
                .toggleStyle(.switch)
                .accessibilityLabel("Test mode")
                .accessibilityHint("When enabled, saving does not overwrite the original string catalog.")
                .accessibilityIdentifier("testModeToggle")

                Button("Make Default App for .xcstrings") {
                    makeDefaultAppForStringCatalogs()
                }
                .accessibilityHint("Sets XCStrings translator as the default app for string catalogs.")
                .accessibilityIdentifier("makeDefaultAppButton")

                if let defaultAppStatus {
                    Text(defaultAppStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Default app status")
                        .accessibilityValue(defaultAppStatus)
                }
            } header: {
                Label("Settings", systemImage: "gear")
            }
        } bottomContent: {

        }
        .toolbar {
                Button("Close") {
                    dismiss()
                }
                .accessibilityHint("Closes the settings window.")
                .accessibilityIdentifier("closeSettingsButton")
        }
        .frame(minWidth: 500, minHeight: 500)
    }

    /// Registers this app as the default opener for `.xcstrings` files.
    ///
    /// Side Effects:
    /// Calls Launch Services through `DefaultStringCatalogAppManager` and updates
    /// `defaultAppStatus` with the result.
    private func makeDefaultAppForStringCatalogs() {
        DefaultStringCatalogAppManager.setAsDefault { result in
            switch result {
            case let .failure(error):
                defaultAppStatus = "Could not set default app: \(error.localizedDescription)"
            case .success:
                defaultAppStatus = "XCStrings translator is now the default app for .xcstrings files."
            }
        }
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
