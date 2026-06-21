//
//  ContentView.swift
//  XCStrings Translator
//
//  Created by Wesley de Groot on 31/01/2025.
//

import SwiftUI
import Translation
import FilePicker
import OSLog
import Foundation
import UniformTypeIdentifiers

enum TranslationTargetSelection: Hashable {
    case language(Locale.Language)
    case allAvailable
}

/// Converts the user's target-language choice into concrete Translation framework targets.
///
/// The Translation framework rejects some regional same-language pairs, such as
/// `en-IN` to `en-CA`. For "all languages", the resolver filters out both the exact
/// source identifier and targets that share the same base language code.
struct TranslationTargetsResolver {
    static func targets(
        for selection: TranslationTargetSelection?,
        sourceLanguage: Locale.Language?,
        supportedLanguages: [Locale.Language]
    ) -> [Locale.Language] {
        guard let selection else {
            return []
        }

        switch selection {
        case .allAvailable:
            let sourceIdentifier = languageIdentifier(for: sourceLanguage)
            let sourceLanguageCode = sourceLanguage?.languageCode?.identifier
            return supportedLanguages.filter {
                languageIdentifier(for: $0) != sourceIdentifier &&
                $0.languageCode?.identifier != sourceLanguageCode
            }
        case let .language(language):
            return [language]
        }
    }

    static func languageIdentifier(for language: Locale.Language?) -> String? {
        guard let language,
              let languageCode = language.languageCode?.identifier else {
            return nil
        }

        if languageCode == "zh",
           let script = language.script?.identifier {
            return "\(languageCode)-\(script)"
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

struct ContentView: View {
    let logger = Logger(
        subsystem: "nl.wesleydegroot.xcstrings-translator",
        category: "User Interface"
    )
    let languageList = LanguageList()
    let languageAvailability = LanguageAvailability()
    private let progressTimer = Timer.publish(
        every: 1,
        on: .main,
        in: .common
    ).autoconnect()

    @StateObject var languageParser = LanguageParser()

    @State var translatedStrings: [String: String] = [:]
    @State var sourceLanguage: Locale.Language?
    @State var destinationSelection: TranslationTargetSelection?
    @State var supportedLanguages: [Locale.Language] = []
    @State var targetLanguageOptions: [Locale.Language] = []
    @State var translationConfiguration: TranslationSession.Configuration?
    @State var status: String = "Idle"
    @State var settingsOpened = false
    @State var exportFile = false
    @State var activeTargetLanguage: Locale.Language?
    @State var pendingTargetLanguages: [Locale.Language] = []
    @State var totalTargetLanguages = 0
    @State var completedTargetLanguages = 0
    @State var totalTranslationUnitsForRun = 0
    @State var completedUnitsBeforeCurrentTarget = 0
    @State var currentTargetTranslationUnits = 0
    @State var skipAlreadyTranslatedForCurrentRun = true
    @State var didFinishTranslation = false
    @State var cancelTranslationRequested = false
    @State var currentTranslation: String?
    @State var translationStartedAt: Date?
    @State var translationEndedAt: Date?
    @State var timerDate = Date()
    @State var defaultAppPromptPresented = false

    // MARK: File Picker

    // FilePicker writes its selected URLs into this binding. The `.onChange` handler
    // below performs the actual load so the same open flow can be reused by onOpenURL.
    @State var filePickerOpen = false
    @State var filePickerFiles: [URL] = []

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
                languageName: languageName(for:)
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
