//
//  ContentView.swift
//  xcstrings-translator
//
//  Created by Wesley de Groot on 31/01/2025.
//

import SwiftUI
import Translation
import FilePicker

struct ContentView: View {
    @State var translatedStrings: [String: String] = [:]
    @State var sourceLanguage: Locale.Language?
    @State var destinationLanguage: Locale.Language?
    @State var supportedLanguages: [Locale.Language] = []
    @State var translationSession: TranslationSession?
    @State var status: String = "Idle"
    @ObservedObject var languageParser = LanguageParser()

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
                Button {
                    translate()
                } label: {
                    HStack {
                        Image(systemName: "translate")
                        Text("Translate")
                    }
                }
                .disabled(translationSession == nil)
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

                Button("Open", systemImage: "square.and.arrow.down") {
                    filePickerOpen.toggle()
                }

                Button("Reload", systemImage: "arrow.clockwise.circle") {
                    status = "Idle"
                    translatedStrings = [:]
                }
                .disabled(languageParser.stringsToTranslate.isEmpty)

                Button("Save", systemImage: "square.and.arrow.up") {
                    languageParser.save()
                }
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
            print(supportedLanguages)
        }
        .filePicker(
            isPresented: $filePickerOpen,
            files: $filePickerFiles,
            types: [.init(filenameExtension: "xcstrings")!]
        )
        .onChange(of: $filePickerFiles.wrappedValue) {
            if let val = $filePickerFiles.wrappedValue.first {
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
            print("Updated session")
            translationSession = session
        }
        .padding()
    }

    func translate() {
        Task {
            if let session = translationSession {
                do {
                    status = "Translating"
                    for string in languageParser.stringsToTranslate {
                        // Perform translation
                        let response = try await session.translate(string)

                        // Update target text
                        print("Translating: \(string), Response: \(response)")
                        translatedStrings[string] = response.targetText
                    }
                    status = "Finished translating, idle"
                } catch {
                    // code to handle error
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
