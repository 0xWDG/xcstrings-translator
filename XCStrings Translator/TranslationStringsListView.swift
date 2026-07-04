//
//  TranslationStringsListView.swift
//  XCStrings Translator
//
//  Created by Wesley de Groot on 21/06/2026.
//

import SwiftUI

/// List of source strings and their current-run translations.
///
/// The list shows all translatable source strings from the loaded catalog. During a
/// run, `currentTranslation` scrolls the active source string into view and
/// `translatedStrings` fills in completed target-language responses.
struct TranslationStringsListView: View {
    /// Source strings extracted from the catalog.
    let stringsToTranslate: [String]
    /// Completed translations for the active target language, keyed by source string.
    let translatedStrings: [String: String]
    /// Source string currently being translated.
    let currentTranslation: String?
    /// Opens the file picker when no catalog is loaded.
    let openFilePicker: () -> Void

    /// Builds the list or empty-state open button.
    var body: some View {
        ScrollViewReader { scrollProxy in
            List {
                if stringsToTranslate.isEmpty {
                    openCatalogButton
                } else {
                    ForEach(stringsToTranslate, id: \.self) { string in
                        TranslationStringRow(
                            string: string,
                            translation: translatedStrings[string]
                        )
                        .id(string)
                    }
                }
            }
            .onChange(of: currentTranslation) { _, newValue in
                guard let newValue else {
                    return
                }

                withAnimation(.easeInOut(duration: 0.25)) {
                    scrollProxy.scrollTo(newValue, anchor: .center)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.quaternary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel("Strings to translate")
        }
    }

    /// Empty-state control that opens a string catalog.
    private var openCatalogButton: some View {
        Button {
            openFilePicker()
        } label: {
            ContentUnavailableView(
                "Open a String Catalog",
                systemImage: "doc.text.magnifyingglass",
                description: Text("Choose an .xcstrings file to see the strings that can be translated.")
            )
            .frame(maxWidth: .infinity, minHeight: 220)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets())
        .accessibilityLabel("Open a string catalog")
        .accessibilityHint("Opens a file picker to choose an .xcstrings file.")
        .accessibilityIdentifier("openEmptyCatalogButton")
    }
}

/// Row showing one source string and its translated value when available.
private struct TranslationStringRow: View {
    /// Source string from the catalog.
    let string: String
    /// Active target-language translation, if completed.
    let translation: String?

    /// Builds the row content.
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(string)
                .font(.body.weight(.medium))

            if let translation, !translation.isEmpty {
                Text(translation)
                    .foregroundStyle(.secondary)
            } else {
                Label("Waiting for translation", systemImage: "hourglass")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }

    /// VoiceOver label for the source text.
    private var accessibilityLabel: String {
        "Source string: \(string)"
    }

    /// VoiceOver value for translated or pending state.
    private var accessibilityValue: String {
        guard let translation, !translation.isEmpty else {
            return "Waiting for translation"
        }

        return "Translation: \(translation)"
    }
}

/// Footer toolbar for settings, opening catalogs, and saving output.
struct TranslationFooterView: View {
    /// Whether translation is active and file actions should be disabled.
    let isTranslating: Bool
    /// Whether the current catalog has saveable translated content.
    let canSave: Bool
    /// Opens the Settings sheet.
    let openSettings: () -> Void
    /// Opens the catalog file picker.
    let openFilePicker: () -> Void
    /// Opens the export panel.
    let save: () -> Void

    /// Builds the footer controls.
    ///
    /// Accessibility:
    /// Buttons use labels, keyboard shortcuts, hints, and stable identifiers so the
    /// controls are reachable by VoiceOver and UI tests.
    var body: some View {
        HStack {
            Button("Settings", systemImage: "gear") {
                openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
            .accessibilityHint("Opens translation settings.")
            .accessibilityIdentifier("settingsButton")

            Spacer()

            Button("Open", systemImage: "square.and.arrow.down") {
                openFilePicker()
            }
            .keyboardShortcut("o", modifiers: .command)
            .disabled(isTranslating)
            .accessibilityHint("Opens a file picker to choose an .xcstrings file.")
            .accessibilityIdentifier("openCatalogButton")

            Button("Save", systemImage: "square.and.arrow.up") {
                save()
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(!canSave)
            .accessibilityHint("Exports the translated string catalog.")
            .accessibilityIdentifier("saveCatalogButton")
        }
        .accessibilityElement(children: .contain)
    }
}
