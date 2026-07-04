//
//  TranslationViews.swift
//  XCStrings Translator
//
//  Created by Wesley de Groot on 21/06/2026.
//

import SwiftUI
import SwiftExtras

/// Header controls for selecting languages and starting translation.
///
/// The view is intentionally stateless beyond its bindings and closures. `ContentView`
/// owns the actual translation workflow; this component only renders the controls and
/// forwards user actions.
struct TranslationHeaderView: View {
    /// Selected source language binding owned by `ContentView`.
    @Binding var sourceLanguage: Locale.Language?
    /// Selected target binding owned by `ContentView`.
    @Binding var destinationSelection: TranslationTargetSelection?

    /// Source languages available through the Translation framework.
    let sourceLanguages: [Locale.Language]
    /// Target languages compatible with the selected source.
    let targetLanguages: [Locale.Language]
    /// Whether an active translation run should disable editing controls.
    let isTranslating: Bool
    /// Whether the Translate action has enough input to run.
    let canTranslate: Bool
    /// Display-name formatter supplied by the coordinator.
    let languageName: (Locale.Language) -> String?
    /// Starts a normal run that respects the "skip already translated" setting.
    let translate: () -> Void
    /// Starts a run that intentionally overwrites existing translations.
    let translateOverwritingExisting: () -> Void

    /// Builds the header layout.
    ///
    /// Accessibility:
    /// Pickers include labels and hints so VoiceOver users can distinguish source and
    /// target language selection. The split action button comes from SwiftExtras and
    /// receives localized titles for both actions.
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

            SplitActionButton(
                primaryTitle: "Translate",
                primarySystemImage: "translate",
                secondaryTitle: "Overwrite All Translations",
                secondarySystemImage: "arrow.triangle.2.circlepath",
                primaryAction: translate,
                secondaryAction: translateOverwritingExisting
            )
            .fixedSize()
            .disabled(!canTranslate)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    TranslationHeaderView(
        sourceLanguage: .constant(.some(.init(identifier: "en"))),
        destinationSelection: .constant(.some(.allAvailable)),
        sourceLanguages: [.init(identifier: "en")],
        targetLanguages: [.init(identifier: "nl")],
        isTranslating: false,
        canTranslate: true
    ) { _ in
            return .localizedName(of: .ascii)
        } translate: {
            //
        } translateOverwritingExisting: {
            //
        }

}
