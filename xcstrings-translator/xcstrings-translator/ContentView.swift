//
//  ContentView.swift
//  xcstrings-translator
//
//  Created by Wesley de Groot on 31/01/2025.
//

import SwiftUI
import Translation
import FilePicker
import OSLog

struct ContentView: View {
    private let logger = Logger(
        subsystem: "nl.wesleydegroot.xcstrings-translator",
        category: "User Interface"
    )

    @ObservedObject var languageParser = LanguageParser()

    @State var translatedStrings: [String: String] = [:]
    @State var sourceLanguage: Locale.Language?
    @State var destinationLanguage: Locale.Language?
    @State var supportedLanguages: [Locale.Language] = []
    @State var translationSession: TranslationSession?
    @State var status: String = "Idle"

    @State var settingsOpened = false

    // MARK: Filepicker
    @State var filePickerOpen = false
    @State var filePickerFiles: [URL] = []

    var body: some View {
        VStack {
            HStack {
                Picker("Source Language", selection: $sourceLanguage) {
                    ForEach(supportedLanguages, id: \.self) { language in
                        if let code = language.languageCode {
                            Text(
                                LanguageList()
                                    .language(for: language)?.name ?? "\(code)"
                            )
                            .tag(language)
                        }
                    }
                }
                .frame(maxWidth: 300)
                Spacer()
                Picker("Target Language", selection: $destinationLanguage) {
                    ForEach(supportedLanguages, id: \.self) { language in
                        if let code = language.languageCode {
                                Text(
                                LanguageList()
                                    .language(for: language)?.name ?? "\(code)"
                            )
                            .tag(language)
                        }
                    }
                }
                .frame(maxWidth: 300)
                Picker("state", selection: $languageParser.state) {
                    ForEach(LanguageParser.LPState.allCases, id: \.rawValue) { state in
                        Text(state.humanReadableName)
                            .tag(state)
                    }
                }
                .frame(maxWidth: 150)
                Button("Translate", systemImage: "translate") {
                    translate()
                }
                .keyboardShortcut("t", modifiers: .command)
                .disabled(
                    translationSession == nil ||
                    languageParser.stringsToTranslate.isEmpty
                )
            }
            List {
                ForEach(languageParser.stringsToTranslate, id: \.self) { string in
                    HStack {
                        LabeledContent(
                            string,
                            value: translatedStrings[string] ?? ""
                        )
                        // if !shouldTranslate {
                        // }
                    }
                }
            }

            HStack {
                Text("Status: \(status).")
                Spacer()
                Text(
                    "Translated: \(translatedStrings.count)/\(languageParser.stringsToTranslate.count)"
                )

                Button("Settings", systemImage: "gear") {
                    settingsOpened.toggle()
                }
                .keyboardShortcut(",", modifiers: .command)
                Button("Open", systemImage: "square.and.arrow.down") {
                    filePickerOpen.toggle()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Reload", systemImage: "arrow.clockwise.circle") {
                    status = "Idle"
                    translatedStrings = [:]
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(languageParser.stringsToTranslate.isEmpty)

                Button("Save", systemImage: "square.and.arrow.up") {
                    languageParser.save()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(
                    languageParser.stringsToTranslate.isEmpty ||
                    translatedStrings.count != languageParser.stringsToTranslate.count
                )
            }
        }
        .navigationTitle("xcstrings Translator")
        .task {
            supportedLanguages = await LanguageAvailability().supportedLanguages
            destinationLanguage = supportedLanguages.first(where: { $0.languageCode == "nl" })
            sourceLanguage = supportedLanguages.first(where: { $0.languageCode == "en" })

            dump(supportedLanguages)
        }
        .filePicker(
            isPresented: $filePickerOpen,
            files: $filePickerFiles,
            types: [.init(filenameExtension: "xcstrings")!] // swiftlint:disable:this force_unwrapping
        )
        .sheet(isPresented: $settingsOpened) {
            SettingsView()
                .environmentObject(languageParser)
        }
        .onChange(of: $filePickerFiles.wrappedValue) {
            if let val = $filePickerFiles.wrappedValue.first {
                status = "Idle"
                translatedStrings = [:]
                languageParser.load(file: val)
                sourceLanguage = supportedLanguages.first(where: {
                    $0.languageCode == Locale.Language(
                        identifier: languageParser.sourceLanguage
                    ).languageCode
                })
            }
        }
        .translationTask(
            source: sourceLanguage,
            target: destinationLanguage
        ) { session in
            logger.debug("Updated session")
            translationSession = session
        }
        .padding()
    }

    func translate() {
        Task {
            if let session = translationSession {
                do {
                    status = "Translating"
                    for string in languageParser.stringsToTranslate where !string.isEmpty {
                        // Perform translation
                        let response = try await session.translate(string)
                        translatedStrings[string] = response.targetText
                        languageParser.add(translation: response)
                    }
                    status = "Finished translating, idle"
                } catch {
                    // code to handle error
                    logger
                        .error(
                            "Translation failed: \(error.localizedDescription, privacy: .public)"
                        )
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
