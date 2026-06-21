//
//  TranslationViews.swift
//  XCStrings Translator
//
//  Created by Wesley de Groot on 21/06/2026.
//

import SwiftUI

struct TranslationHeaderView: View {
    @Binding var sourceLanguage: Locale.Language?
    @Binding var destinationSelection: TranslationTargetSelection?

    let sourceLanguages: [Locale.Language]
    let targetLanguages: [Locale.Language]
    let isTranslating: Bool
    let canTranslate: Bool
    let languageName: (Locale.Language) -> String?
    let translate: () -> Void
    let translateOverwritingExisting: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Translation", systemImage: "text.bubble")
                    .font(.title2.weight(.semibold))
                Text("Choose a source and target, then translate your string catalog.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            Picker("Source Language", selection: $sourceLanguage) {
                ForEach(sourceLanguages, id: \.self) { language in
                    if let code = language.languageCode {
                        Text(languageName(language) ?? "\(code)")
                            .tag(Optional(language))
                    }
                }
            }
            .frame(width: 220)
            .disabled(isTranslating)
            .accessibilityLabel("Source language")
            .accessibilityHint("Choose the language used by the opened string catalog.")

            Picker("Target Language", selection: $destinationSelection) {
                Text("All Available Languages")
                    .tag(Optional(TranslationTargetSelection.allAvailable))

                ForEach(targetLanguages, id: \.self) { language in
                    if let code = language.languageCode {
                        Text(languageName(language) ?? "\(code)")
                            .tag(Optional(TranslationTargetSelection.language(language)))
                    }
                }
            }
            .frame(width: 240)
            .disabled(isTranslating)
            .accessibilityLabel("Target language")
            .accessibilityHint("Choose one target language or all languages available on this Mac.")

            HStack(spacing: 4) {
                Button("Translate", systemImage: "translate") {
                    translate()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("t", modifiers: .command)
                .accessibilityHint("Starts translating the loaded string catalog.")
                .accessibilityIdentifier("translateButton")

                Menu {
                    Button("Overwrite All Translations", systemImage: "arrow.triangle.2.circlepath") {
                        translateOverwritingExisting()
                    }
                    .accessibilityHint("Translates every string again and replaces existing target translations.")
                    .accessibilityIdentifier("overwriteTranslationsButton")
                } label: {
                    Image(systemName: "chevron.down")
                        .accessibilityHidden(true)
                }
                .menuStyle(.button)
                .fixedSize()
                .accessibilityLabel("More translation options")
                .accessibilityHint("Shows additional translation actions.")
                .accessibilityIdentifier("translateOptionsMenu")
            }
            .disabled(!canTranslate)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
