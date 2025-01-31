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
    @State var sourceLanguage: Locale.Language = .init(identifier: "en")
    @State var destinationLanguage: Locale.Language?
    @State var supportedLanguages: [Locale.Language] = []
    @State var translationSession: TranslationSession?
    @State var status: String = "Idle"
    @ObservedObject var lp = LanguageParser()

    // MARK: Filepicker
    @State var filePickerOpen = false
    @State var filePickerFiles: [URL] = []

    var body: some View {
        VStack {
            HStack {
                let language = LanguageList()
                    .language(
                        for: sourceLanguage
                    )?.name ?? "Unknown [\(sourceLanguage.languageCode!)]"
                Text("Source Language (\(language))")
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
                ForEach(lp.stringsToTranslate, id: \.self) { string in
                    HStack {
                        LabeledContent(content: {
                            Text(translatedStrings[string] ?? "")
                        }) {
                            Text(string)
                        }

                        // if !shouldTranslate {
                        // }
                    }
                }
            }
            HStack {
                Text("Status: \(status).")
                Spacer()
                Text(
                    "Translated: \(translatedStrings.count)/\(lp.stringsToTranslate.count)"
                )
                Button("Open", systemImage: "square.and.arrow.down") {
                    filePickerOpen.toggle()
                }

                Button("Reload", systemImage: "arrow.clockwise.circle") {
                    status = "Idle"
                    translatedStrings = [:]
                }

                Button("Save", systemImage: "square.and.arrow.up") {

                    /// ...
                    lp.save()
                }
            }
        }
        .task {
            supportedLanguages = await LanguageAvailability().supportedLanguages
            destinationLanguage = supportedLanguages.first(where: { $0.languageCode == "nl" })
            print(supportedLanguages)
        }
        .filePicker(
            isPresented: $filePickerOpen,
            files: $filePickerFiles,
            types: [.json]
        )
        .onChange(of: $filePickerFiles.wrappedValue) { newValue in
            print(newValue)
            if let val = newValue.first,
               val.absoluteString.hasSuffix("xcstrings") {
                lp.load(file: val)
                sourceLanguage = .init(identifier: lp.sourceLanguage)
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
                    for string in lp.stringsToTranslate {
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
