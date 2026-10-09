//
//  ContentView.swift
//  XCStrings Translator
//
//  Created by Wesley de Groot on 31/01/2025.
//

import Combine
import FilePicker
import Foundation
import OSLog
import SwiftUI
import Translation
import UniformTypeIdentifiers

/// User-facing target-language selection from the header picker.
///
/// The enum separates the UI choice from the resolved Translation framework target
/// list. A single selected language maps to one target, while `allAvailable` is
/// resolved dynamically from the current source language and system support.
enum TranslationTargetSelection: Hashable {
    /// Translate to one specific language.
    case language(Locale.Language)
    /// Translate to every compatible target language available on the current Mac.
    case allAvailable
}

/// Converts the user's target-language choice into concrete Translation framework targets.
///
/// The Translation framework rejects some regional same-language pairs, such as
/// `en-IN` to `en-CA`. For "all languages", the resolver filters out both the exact
/// source identifier and targets that share the same base language code.
struct TranslationTargetsResolver {
    /// Resolves a picker selection into concrete target languages.
    ///
    /// - Parameters:
    ///   - selection: Current target picker value. `nil` means no target has been chosen.
    ///   - sourceLanguage: Source language selected for the catalog.
    ///   - supportedLanguages: Languages reported by the Translation framework for this Mac.
    /// - Returns: Target languages to translate, excluding same-language pairs for
    ///   `allAvailable`.
    static func targets(
        for selection: TranslationTargetSelection?,
        sourceLanguage: Locale.Language?,
        supportedLanguages: [Locale.Language],
        mainLanguagesOnly: Bool = false
    ) -> [Locale.Language] {
        guard let selection else {
            return []
        }

        switch selection {
        case .allAvailable:
            let sourceIdentifier = languageIdentifier(for: sourceLanguage)
            let sourceLanguageCode = sourceLanguage?.languageCode?.identifier
            let targets = supportedLanguages.filter {
                languageIdentifier(for: $0) != sourceIdentifier &&
                $0.languageCode?.identifier != sourceLanguageCode
            }
            return mainLanguagesOnly ? mainLanguages(from: targets) : targets
        case let .language(language):
            return [language]
        }
    }

    /// Keeps one system-supported canonical representative for each variant group.
    ///
    /// The representative retains its regional identifier for Translation framework
    /// compatibility, while its catalog output uses `mainLanguageIdentifier(for:)`
    /// only when that group contains multiple available variants.
    /// When the canonical variant is available, it is preferred over another regional
    /// variant: for example, `fr-FR` over `fr-CA` and `nl-NL` over `nl-BE`.
    static func mainLanguages(from languages: [Locale.Language]) -> [Locale.Language] {
        var representatives: [String: Locale.Language] = [:]

        for language in languages {
            guard let identifier = variantGroupIdentifier(for: language) else {
                continue
            }

            guard let existingRepresentative = representatives[identifier] else {
                representatives[identifier] = language
                continue
            }

            if isCanonicalMainLanguageVariant(language, in: identifier),
               !isCanonicalMainLanguageVariant(existingRepresentative, in: identifier) {
                representatives[identifier] = language
            }
        }

        return languages.filter { language in
            guard let identifier = variantGroupIdentifier(for: language) else {
                return false
            }

            return representatives[identifier] == language
        }
    }

    /// Returns whether an available target has multiple interchangeable variants.
    ///
    /// Chinese script variants deliberately form separate groups, so Simplified and
    /// Traditional Chinese remain independent targets even when main-language mode is
    /// enabled.
    static func shouldCollapseToMainLanguage(
        _ language: Locale.Language?,
        among availableLanguages: [Locale.Language]
    ) -> Bool {
        guard let groupIdentifier = variantGroupIdentifier(for: language) else {
            return false
        }

        return availableLanguages.filter {
            variantGroupIdentifier(for: $0) == groupIdentifier
        }.count > 1
    }

    /// Returns the catalog key for a target under the selected granularity.
    ///
    /// A lone regional target, such as `uk-UA`, retains its regional identifier so it
    /// remains available. Only groups with multiple choices use a base-language key.
    static func targetLanguageIdentifier(
        for language: Locale.Language?,
        mainLanguagesOnly: Bool,
        availableLanguages: [Locale.Language]
    ) -> String? {
        guard mainLanguagesOnly,
              shouldCollapseToMainLanguage(language, among: availableLanguages) else {
            return languageIdentifier(for: language)
        }

        return mainLanguageIdentifier(for: language)
    }

    /// Identifies the Unicode CLDR maximal locale variant for a variant group.
    ///
    /// - Parameter language: A system-supported language variant.
    /// - Returns: `true` when `language` matches the canonical maximal variant for
    ///   its group, such as `fr-Latn-FR` for French or `zh-Hant-TW` for
    ///   Traditional Chinese.
    private static func isCanonicalMainLanguageVariant(
        _ language: Locale.Language,
        in groupIdentifier: String
    ) -> Bool {
        guard !groupIdentifier.isEmpty else {
            return false
        }

        return language.maximalIdentifier == Locale.Language(
            identifier: groupIdentifier
        ).maximalIdentifier
    }

    /// Returns a grouping key for main-language selection.
    ///
    /// Chinese includes its script because `zh-Hans` and `zh-Hant` represent distinct
    /// written languages. All other languages group by their base language code.
    private static func variantGroupIdentifier(for language: Locale.Language?) -> String? {
        guard let language,
              let languageCode = language.languageCode?.identifier else {
            return nil
        }

        if languageCode == "zh",
           let script = language.script?.identifier {
            return "\(languageCode)-\(script)"
        }

        return languageCode
    }

    /// Returns the language-code identifier shared by all regional and script variants.
    static func mainLanguageIdentifier(for language: Locale.Language?) -> String? {
        language?.languageCode?.identifier
    }

    /// Returns the catalog identifier this app uses for a Translation framework language.
    ///
    /// - Parameter language: Language value from Swift's `Locale.Language` APIs.
    /// - Returns: A stable `.xcstrings` localization key, or `nil` when the language
    ///   does not expose a language code.
    ///
    /// Implementation Notes:
    /// Xcode catalogs commonly use BCP-47 identifiers, but Apple's Translation
    /// framework may expose regional identifiers for languages where catalogs usually
    /// store a generic key. This method centralizes those compatibility rules so UI,
    /// parsing, skipping, and saving all agree on the same identifier.
    static func languageIdentifier(for language: Locale.Language?) -> String? {
        guard let language,
              let languageCode = language.languageCode?.identifier else {
            return nil
        }

        if languageCode == "zh",
           let script = language.script?.identifier {
            return "\(languageCode)-\(script)"
        }

        if ["da", "vi", "sv"].contains(languageCode.lowercased()) {
            // da-DK = DAnish, for DenmarK
            // vi-VN = VIetnamese, for VietNam
            // sv-SE = Swedish, for SwEden [???]
            return languageCode
        }

        // if the language is not nl-NL or it-IT, xx-xx, just the language code,
        // so that if we don't support a regional translation, we can fallback on the OG.
        if languageCode.lowercased() == language.region?.identifier.lowercased() {
            return languageCode
        }

        // Most .xcstrings files use BCP-47 language keys. Preserve the region for
        // languages where region-specific translations are distinct catalog entries.
        if let region = language.region?.identifier {
            return "\(languageCode)-\(region)"
        }

        if language.minimalIdentifier.contains("-") {
            return language.minimalIdentifier
        }

        return languageCode
    }
}

/// Root SwiftUI view for the translation workflow.
///
/// Purpose:
/// Coordinates file loading, language selection, Translation framework sessions,
/// progress state, saving, settings, and the default-app prompt.
///
/// Architecture:
/// `ContentView` owns UI state and delegates catalog mutation to `LanguageParser`.
/// Translation is split across extensions:
/// `ContentView+Translation` handles UI actions and lifecycle state,
/// `ContentView+TranslationTargets` filters language pairs, `ContentView+TranslationRun`
/// executes asynchronous translation sessions, and `ContentView+ProgressState`
/// derives display metrics.
///
/// Thread Safety:
/// SwiftUI evaluates this view on the main actor. Methods that mutate view state are
/// annotated `@MainActor` in extensions when they can be called from async tasks.
struct ContentView: View {
    /// UI logger for user-triggered translation and save events.
    let logger = Logger(
        subsystem: "nl.wesleydegroot.xcstrings-translator",
        category: "User Interface"
    )
    /// Translation framework availability provider used to discover supported pairs.
    let languageAvailability = LanguageAvailability()
    /// Timer used only while translating to refresh elapsed-time and ETA labels.
    private let progressTimer = Timer.publish(
        every: 1,
        on: .main,
        in: .common
    ).autoconnect()

    // swiftlint:disable private_swiftui_state
    // These properties are internal only so ContentView extensions in companion files
    // can coordinate one translation workflow. Swift's `private` is file-scoped.
    /// Shared catalog model observed by all workflow and settings views.
    @StateObject var languageParser = LanguageParser()

    /// Translations completed for the currently active target language.
    @State var translatedStrings: [String: String] = [:]
    /// Source language selected in the header picker.
    @State var sourceLanguage: Locale.Language?
    /// Target picker value before it is resolved into concrete languages.
    @State var destinationSelection: TranslationTargetSelection?
    /// System-supported languages reported by the Translation framework.
    @State var supportedLanguages: [Locale.Language] = []
    /// Target languages compatible with the selected source language.
    @State var targetLanguageOptions: [Locale.Language] = []
    /// Non-nil configuration drives SwiftUI's `translationTask` modifier.
    @State var translationConfiguration: TranslationSession.Configuration?
    /// Human-readable status shown in the progress panel.
    @State var status: String = "Idle"
    /// Controls presentation of the Settings sheet.
    @State private var settingsOpened = false
    /// Controls presentation of SwiftUI's export panel.
    @State private var exportFile = false
    /// Target language currently being translated.
    @State var activeTargetLanguage: Locale.Language?
    /// Remaining target languages queued after the active target finishes.
    @State var pendingTargetLanguages: [Locale.Language] = []
    /// Total target languages in the current run.
    @State var totalTargetLanguages = 0
    /// Target languages fully completed in the current run.
    @State var completedTargetLanguages = 0
    /// Total string-language units planned for the current run.
    @State var totalTranslationUnitsForRun = 0
    /// Completed units from previous target languages in the current run.
    @State var completedUnitsBeforeCurrentTarget = 0
    /// Units planned for the active target language.
    @State var currentTargetTranslationUnits = 0
    /// Snapshot of the skip setting for the current run.
    @State var skipAlreadyTranslatedForCurrentRun = true
    /// Snapshot of target-language granularity for the current run.
    @State var mainLanguagesOnlyForCurrentRun = true
    /// Whether the latest run completed without cancellation or failure.
    @State var didFinishTranslation = false
    /// Cooperative cancellation flag checked before and after each translation request.
    @State var cancelTranslationRequested = false
    /// Source string currently being translated, used to scroll the list.
    @State var currentTranslation: String?
    /// Start time for elapsed-time and ETA calculation.
    @State var translationStartedAt: Date?
    /// End time for completed, cancelled, or failed runs.
    @State var translationEndedAt: Date?
    /// Timer-driven clock value used while a run is active.
    @State var timerDate = Date()
    /// Controls the post-translation default-app prompt.
    @State var defaultAppPromptPresented = false
    // swiftlint:enable private_swiftui_state

    // MARK: File Picker

    /// Controls presentation of the FilePicker package's open panel.
    @State private var filePickerOpen = false
    /// URLs selected by FilePicker.
    ///
    /// FilePicker writes its selected URLs into this binding. The `.onChange` handler
    /// performs the actual load so the same `openStringCatalog(_:)` flow can be reused
    /// by Finder/Open URL events.
    @State private var filePickerFiles: [URL] = []

    /// Builds the main translation window.
    ///
    /// Side Effects:
    /// View modifiers start language discovery, open and export files, respond to
    /// picker changes, drive Translation framework tasks, and update Dock progress.
    var body: some View {
        VStack(spacing: 16) {
            TranslationHeaderView(
                sourceLanguage: $sourceLanguage,
                destinationSelection: $destinationSelection,
                sourceLanguages: supportedLanguages,
                targetLanguages: targetLanguageOptions,
                isTranslating: isTranslating,
                canTranslate: canTranslate,
                languageName: languageName(for:),
                translate: {
                    Task {
                        await translate()
                    }
                },
                translateOverwritingExisting: {
                    Task {
                        await translate(overwritingExistingTranslations: true)
                    }
                },
                translateOnlyExistingLanguages: {
                    Task {
                        await translate(onlyUpdatingExistingLanguages: true)
                    }
                },
                translateAllLanguageVariants: {
                    Task {
                        await translate(includingAllLanguageVariants: true)
                    }
                }
            )

            TranslationProgressView(
                status: status,
                progressValue: progressValue,
                completedUnits: completedTranslationUnits,
                totalUnits: totalTranslationUnits,
                translatedStrings: translatedStrings.count,
                stringsToTranslate: progressStringsToTranslate,
                completedLanguages: completedTargetLanguages,
                totalLanguages: selectedTargetCount,
                elapsedTime: elapsedTranslationText,
                estimatedTimeRemaining: estimatedTimeRemainingText,
                isTranslating: isTranslating,
                didFinishTranslation: didFinishTranslation,
                cancelTranslation: cancelTranslation
            )

            TranslationStringsListView(
                stringsToTranslate: languageParser.stringsToTranslate,
                translatedStrings: translatedStrings,
                currentTranslation: currentTranslation,
                openFilePicker: {
                    filePickerOpen.toggle()
                }
            )

            TranslationFooterView(
                isTranslating: isTranslating,
                canSave: canSave,
                openSettings: {
                    settingsOpened.toggle()
                },
                openFilePicker: {
                    filePickerOpen.toggle()
                },
                save: {
                    exportFile.toggle()
                }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle("XCStrings translator")
        .task {
            await configureInitialLanguages()
        }
        .filePicker(
            isPresented: $filePickerOpen,
            files: $filePickerFiles,
            types: [.xcstrings]
        )
        .fileExporter(
            isPresented: $exportFile,
            document: XCStringsExportDocument(data: languageParser.data),
            contentType: .xcstrings,
            defaultFilename: "Localizable.xcstrings"
        ) { _ in
            exportFile = false
        }
        .sheet(isPresented: $settingsOpened) {
            SettingsView(
                supportedLanguages: targetLanguageOptions,
                languageName: languageName(for:),
                languageIdentifier: { language in
                    targetLanguageIdentifier(for: language)
                }
            )
                .environmentObject(languageParser)
        }
        .alert(
            "Make XCStrings translator the default app?",
            isPresented: $defaultAppPromptPresented
        ) {
            Button("Set as Default") {
                setDefaultStringCatalogApp()
            }
            .accessibilityHint("Sets this app as the default opener for .xcstrings files.")
            .accessibilityIdentifier("setDefaultAppAlertButton")
            Button("Not Now", role: .cancel) {
                DefaultStringCatalogAppManager.didRespondToPrompt = true
            }
            .accessibilityHint("Dismisses this prompt and does not ask again.")
            .accessibilityIdentifier("dismissDefaultAppAlertButton")
        } message: {
            Text("Open .xcstrings files directly in XCStrings translator from Finder and the Open With menu.")
        }
        .onOpenURL { url in
            openStringCatalog(url)
        }
        .onChange(of: filePickerFiles) { _, newFiles in
            if let url = newFiles.first {
                openStringCatalog(url)
            }
        }
        .onChange(of: destinationSelection) { oldValue, newValue in
            guard oldValue != newValue else {
                return
            }

            resetTranslationState()
        }
        .onChange(of: sourceLanguage) { oldValue, newValue in
            guard oldValue != newValue else {
                return
            }

            resetTranslationState()
            Task {
                await refreshAvailableTargetLanguages(selectDefaultTarget: true)
            }
        }
        .onChange(of: languageParser.skipAlreadyTranslated) {
            resetTranslationState()
        }
        .onChange(of: languageParser.mainLanguagesOnly) {
            resetTranslationState()
            Task {
                await refreshAvailableTargetLanguages(selectDefaultTarget: true)
            }
        }
        .onChange(of: languageParser.removeStaleTranslations) { _, shouldRemove in
            guard shouldRemove else {
                return
            }

            if languageParser.removeStaleEntries() > 0 {
                resetTranslationState()
            }
        }
        .onChange(of: languageParser.defaultTargetLanguageIdentifier) {
            setDestinationSelectionIfNeeded(defaultDestinationSelection())
            resetTranslationState()
        }
        .translationTask(translationConfiguration) { session in
            await translate(using: session)
        }
        .onReceive(progressTimer) { date in
            if isTranslating {
                timerDate = date
            }
        }
        .onChange(of: progressValue) {
            updateDockProgress()
        }
        .onChange(of: isTranslating) {
            updateDockProgress()
        }
        .onDisappear {
            DockProgressController.shared.clear()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("contentView")
    }
}

#Preview {
    ContentView()
}
// swiftlint:disable:this file_length
