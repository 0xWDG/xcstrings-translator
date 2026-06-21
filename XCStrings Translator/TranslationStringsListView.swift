//
//  TranslationStringsListView.swift
//  XCStrings Translator
//
//  Created by Wesley de Groot on 21/06/2026.
//

import SwiftUI

struct TranslationStringsListView: View {
    let stringsToTranslate: [String]
    let translatedStrings: [String: String]
    let currentTranslation: String?
    let openFilePicker: () -> Void

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

private struct TranslationStringRow: View {
    let string: String
    let translation: String?

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

    private var accessibilityLabel: String {
        "Source string: \(string)"
    }

    private var accessibilityValue: String {
        guard let translation, !translation.isEmpty else {
            return "Waiting for translation"
        }

        return "Translation: \(translation)"
    }
}

struct TranslationFooterView: View {
    let isTranslating: Bool
    let canSave: Bool
    let openSettings: () -> Void
    let openFilePicker: () -> Void
    let save: () -> Void

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
