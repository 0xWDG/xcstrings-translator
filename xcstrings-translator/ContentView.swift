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
import Foundation
import UniformTypeIdentifiers

enum TranslationTargetSelection: Hashable {
    case language(Locale.Language)
    case allAvailable
}

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
    private let logger = Logger(
        subsystem: "nl.wesleydegroot.xcstrings-translator",
        category: "User Interface"
    )
    private let languageList = LanguageList()
    private let languageAvailability = LanguageAvailability()
    private let progressTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @ObservedObject var languageParser = LanguageParser()

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
    @State var completedTranslationUnitsBeforeCurrentTarget = 0
    @State var currentTargetTranslationUnits = 0
    @State var didFinishTranslation = false
    @State var cancelTranslationRequested = false
    @State var currentTranslation: String?
    @State var translationStartedAt: Date?
    @State var translationEndedAt: Date?
    @State var timerDate = Date()

    // MARK: Filepicker
    @State var filePickerOpen = false
    @State var filePickerFiles: [URL] = []

    private var isTranslating: Bool {
        translationConfiguration != nil
    }

    private var availableTargetLanguages: [Locale.Language] {
        TranslationTargetsResolver.targets(
            for: destinationSelection,
            sourceLanguage: sourceLanguage,
            supportedLanguages: targetLanguageOptions
        )
    }

    private var canTranslate: Bool {
        !isTranslating &&
        sourceLanguage != nil &&
        !languageParser.stringsToTranslate.isEmpty &&
        !availableTargetLanguages.isEmpty
    }

    private var canSave: Bool {
        !isTranslating &&
        !languageParser.stringsToTranslate.isEmpty &&
        didFinishTranslation
    }

    private var totalTranslationUnits: Int {
        if totalTranslationUnitsForRun > 0 {
            return totalTranslationUnitsForRun
        }

        return languageParser.stringsToTranslate.count * max(availableTargetLanguages.count, 1)
    }

    private var completedTranslationUnits: Int {
        if isTranslating {
            return completedTranslationUnitsBeforeCurrentTarget + translatedStrings.count
        }

        if didFinishTranslation {
            return totalTranslationUnits
        }

        return translatedStrings.count
    }

    private var progressValue: Double {
        guard totalTranslationUnits > 0 else {
            return 0
        }

        return min(Double(completedTranslationUnits) / Double(totalTranslationUnits), 1)
    }

    private var selectedTargetCount: Int {
        if totalTargetLanguages > 0 {
            return totalTargetLanguages
        }

        return availableTargetLanguages.count
    }

    private var progressStringsToTranslate: Int {
        if isTranslating || currentTargetTranslationUnits > 0 {
            return currentTargetTranslationUnits
        }

        return languageParser.stringsToTranslate.count
    }

    private var elapsedTranslationTime: TimeInterval {
        guard let translationStartedAt else {
            return 0
        }

        return max((translationEndedAt ?? timerDate).timeIntervalSince(translationStartedAt), 0)
    }

    private var elapsedTranslationText: String {
        guard translationStartedAt != nil else {
            return "Not started"
        }

        return formattedDuration(elapsedTranslationTime)
    }

    private var estimatedTimeRemainingText: String {
        guard translationStartedAt != nil else {
            return "Not started"
        }

        guard isTranslating else {
            return didFinishTranslation ? "Done" : "Stopped"
        }

        guard completedTranslationUnits > 0,
              totalTranslationUnits > completedTranslationUnits,
              elapsedTranslationTime > 0 else {
            return "Calculating"
        }

        let unitsPerSecond = Double(completedTranslationUnits) / elapsedTranslationTime

        guard unitsPerSecond > 0 else {
            return "Calculating"
        }

        let remainingUnits = totalTranslationUnits - completedTranslationUnits
        return formattedDuration(Double(remainingUnits) / unitsPerSecond)
    }

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
        .navigationTitle("xcstrings Translator")
        .task {
            supportedLanguages = await languageAvailability.supportedLanguages
            sourceLanguage = supportedLanguages.first(where: { $0.languageCode == "en" })
            targetLanguageOptions = await availableSystemTargetLanguages()
            destinationSelection = defaultDestinationSelection()
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
        .onChange(of: $filePickerFiles.wrappedValue) {
            if let val = $filePickerFiles.wrappedValue.first {
                resetTranslationState()
                languageParser.load(file: val)
                sourceLanguage = supportedLanguages.first(where: {
                    $0.languageCode == Locale.Language(
                        identifier: languageParser.sourceLanguage
                    ).languageCode
                })
            }
        }
        .onChange(of: $destinationSelection.wrappedValue) {
            resetTranslationState()
        }
        .onChange(of: $sourceLanguage.wrappedValue) {
            resetTranslationState()
            Task {
                targetLanguageOptions = await availableSystemTargetLanguages()
                destinationSelection = defaultDestinationSelection()
            }
        }
        .onChange(of: languageParser.skipAlreadyTranslated) {
            resetTranslationState()
        }
        .onChange(of: languageParser.defaultTargetLanguageIdentifier) {
            destinationSelection = defaultDestinationSelection()
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
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func languageName(for language: Locale.Language) -> String? {
        languageList.language(for: language)?.name
    }

    private func defaultDestinationSelection() -> TranslationTargetSelection {
        let identifier = languageParser.defaultTargetLanguageIdentifier

        guard identifier != LanguageParser.allLanguagesDefaultTargetIdentifier else {
            return .allAvailable
        }

        if let language = targetLanguageOptions.first(where: {
            TranslationTargetsResolver.languageIdentifier(for: $0) == identifier ||
            $0.minimalIdentifier == identifier ||
            $0.maximalIdentifier == identifier
        }) {
            return .language(language)
        }

        return .allAvailable
    }

    @MainActor
    private func resetTranslationState() {
        translatedStrings = [:]
        translationConfiguration = nil
        activeTargetLanguage = nil
        pendingTargetLanguages = []
        totalTargetLanguages = 0
        completedTargetLanguages = 0
        totalTranslationUnitsForRun = 0
        completedTranslationUnitsBeforeCurrentTarget = 0
        currentTargetTranslationUnits = 0
        didFinishTranslation = false
        cancelTranslationRequested = false
        currentTranslation = nil
        translationStartedAt = nil
        translationEndedAt = nil
        timerDate = Date()
        status = "Idle"
    }

    @MainActor
    private func beginTranslation(for targetLanguage: Locale.Language) {
        activeTargetLanguage = targetLanguage
        translatedStrings = [:]
        currentTranslation = nil
        currentTargetTranslationUnits = stringsToTranslate(for: targetLanguage).count
        status = translationStatus(
            for: targetLanguage,
            completedTargets: completedTargetLanguages,
            totalTargets: totalTargetLanguages
        )
        translationConfiguration = TranslationSession.Configuration(
            source: sourceLanguage,
            target: targetLanguage
        )
    }

    private func translationStatus(
        for targetLanguage: Locale.Language,
        completedTargets: Int,
        totalTargets: Int
    ) -> String {
        let targetName = languageName(for: targetLanguage) ??
            TranslationTargetsResolver.languageIdentifier(for: targetLanguage) ??
            targetLanguage.maximalIdentifier

        if totalTargets > 1 {
            return "Translating \(targetName) (\(completedTargets + 1)/\(totalTargets))"
        }

        return "Translating \(targetName)"
    }

    @MainActor
    private func cancelTranslation() {
        cancelTranslationRequested = true
        translationConfiguration = nil
        activeTargetLanguage = nil
        pendingTargetLanguages = []
        currentTranslation = nil
        currentTargetTranslationUnits = 0
        translationEndedAt = Date()
        timerDate = translationEndedAt ?? Date()
        didFinishTranslation = false
        status = "Translation cancelled"
    }

    @MainActor
    private func finishCurrentTarget() {
        guard !cancelTranslationRequested else {
            return
        }

        completedTargetLanguages += 1
        completedTranslationUnitsBeforeCurrentTarget += currentTargetTranslationUnits

        if let nextTargetLanguage = pendingTargetLanguages.first {
            pendingTargetLanguages.removeFirst()
            beginTranslation(for: nextTargetLanguage)
            return
        }

        activeTargetLanguage = nil
        translationConfiguration = nil
        currentTranslation = nil
        currentTargetTranslationUnits = 0
        translationEndedAt = Date()
        timerDate = translationEndedAt ?? Date()
        didFinishTranslation = true

        if totalTargetLanguages > 1 {
            status = "Finished translating \(completedTargetLanguages) languages, idle"
        } else {
            status = "Finished translating, idle"
        }

        autoSaveIfNeeded()
    }

    @MainActor
    private func autoSaveIfNeeded() {
        guard languageParser.autoSaveTranslations else {
            return
        }

        do {
            switch try languageParser.saveToLoadedFile() {
            case .saved:
                status = "Finished translating and saved"
            case .skippedTesting:
                status = "Finished translating, auto-save skipped in Test Mode"
            }
        } catch {
            logger.error("Automatic save failed: \(error.localizedDescription, privacy: .public)")
            status = "Finished translating, automatic save failed"
        }
    }

    @MainActor
    private func failTranslation(_ error: Error) {
        logger.error(
            "Translation failed: \(error.localizedDescription, privacy: .public)"
        )
        translationConfiguration = nil
        activeTargetLanguage = nil
        pendingTargetLanguages = []
        currentTranslation = nil
        currentTargetTranslationUnits = 0
        translationEndedAt = Date()
        timerDate = translationEndedAt ?? Date()
        didFinishTranslation = false
        status = "Translation failed"
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(Int(duration.rounded()), 0)
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }

        return "\(seconds)s"
    }

    private func stringsToTranslate(for targetLanguage: Locale.Language?) -> [String] {
        languageParser.stringsToTranslate(
            forLanguage: TranslationTargetsResolver.languageIdentifier(for: targetLanguage),
            skippingTranslated: languageParser.skipAlreadyTranslated
        )
    }

    private func totalTranslationUnits(for targetLanguages: [Locale.Language]) -> Int {
        targetLanguages.reduce(0) { partialResult, targetLanguage in
            partialResult + stringsToTranslate(for: targetLanguage).count
        }
    }

    private func isTranslationPairAvailable(
        source: Locale.Language,
        target: Locale.Language
    ) async -> Bool {
        let status = await languageAvailability.status(from: source, to: target)

        switch status {
        case .installed, .supported:
            return true
        case .unsupported:
            logger.debug(
                "Skipping unsupported translation pair: \(source.maximalIdentifier, privacy: .public)-\(target.maximalIdentifier, privacy: .public)"
            )
            return false
        @unknown default:
            return false
        }
    }

    private func availableSystemTargetLanguages() async -> [Locale.Language] {
        guard let sourceLanguage else {
            return []
        }

        var availableLanguages: [Locale.Language] = []

        for targetLanguage in supportedLanguages {
            guard TranslationTargetsResolver.languageIdentifier(for: targetLanguage) !=
                    TranslationTargetsResolver.languageIdentifier(for: sourceLanguage),
                  targetLanguage.languageCode?.identifier != sourceLanguage.languageCode?.identifier,
                  await isTranslationPairAvailable(source: sourceLanguage, target: targetLanguage) else {
                continue
            }

            availableLanguages.append(targetLanguage)
        }

        return availableLanguages
    }

    @MainActor
    private func compatibleTargetLanguages(
        from targetLanguages: [Locale.Language]
    ) async -> [Locale.Language] {
        guard let sourceLanguage else {
            return []
        }

        status = "Checking available translation languages"

        var compatibleLanguages: [Locale.Language] = []

        for targetLanguage in targetLanguages
        where await isTranslationPairAvailable(
            source: sourceLanguage,
            target: targetLanguage
        ) {
            compatibleLanguages.append(targetLanguage)
        }

        return compatibleLanguages
    }

    func translate() async {
        let targetLanguages = await compatibleTargetLanguages(from: availableTargetLanguages)

        guard !targetLanguages.isEmpty else {
            await MainActor.run {
                status = "No compatible translation languages available"
            }
            return
        }

        let targetLanguagesWithWork = await MainActor.run {
            targetLanguages.filter { targetLanguage in
                !stringsToTranslate(for: targetLanguage).isEmpty
            }
        }

        guard !targetLanguagesWithWork.isEmpty else {
            await MainActor.run {
                resetTranslationState()
                status = "No untranslated strings available"
            }
            return
        }

        let totalTranslationUnits = await MainActor.run(resultType: Int.self) {
            self.totalTranslationUnits(for: targetLanguagesWithWork)
        }

        guard totalTranslationUnits > 0 else {
            await MainActor.run {
                resetTranslationState()
                status = "No untranslated strings available"
            }
            return
        }

        await MainActor.run {
            cancelTranslationRequested = false
            didFinishTranslation = false
            completedTargetLanguages = 0
            completedTranslationUnitsBeforeCurrentTarget = 0
            totalTranslationUnitsForRun = totalTranslationUnits
            totalTargetLanguages = targetLanguagesWithWork.count
            pendingTargetLanguages = Array(targetLanguagesWithWork.dropFirst())
            translationStartedAt = Date()
            translationEndedAt = nil
            timerDate = translationStartedAt ?? Date()

            if let firstTargetLanguage = targetLanguagesWithWork.first {
                beginTranslation(for: firstTargetLanguage)
            }
        }
    }

    private func translate(using session: TranslationSession) async {
        let stringsToTranslate = await MainActor.run(resultType: [String].self) {
            self.stringsToTranslate(for: activeTargetLanguage)
        }
        let targetLanguage = await MainActor.run { activeTargetLanguage }

        guard targetLanguage != nil else {
            return
        }

        do {
            for string in stringsToTranslate {
            if await MainActor.run(resultType: Bool.self, body: {
                cancelTranslationRequested
            }) {
                return
            }

            await MainActor.run {
                currentTranslation = string
            }

            let response = try await session.translate(string)

                await MainActor.run {
                    guard !cancelTranslationRequested else {
                        return
                    }

                    translatedStrings[response.sourceText] = response.targetText
                    languageParser.add(translation: response)
                }
            }

            await MainActor.run {
                finishCurrentTarget()
            }
        } catch {
            if await MainActor.run(resultType: Bool.self, body: {
                cancelTranslationRequested
            }) {
                return
            }

            await MainActor.run {
                failTranslation(error)
            }
        }
    }
}

private extension UTType {
    static let xcstrings = UTType(importedAs: "com.apple.xcode.xcstrings", conformingTo: .json)
}

private struct XCStringsExportDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.xcstrings]
    }

    static var writableContentTypes: [UTType] {
        [.xcstrings]
    }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    ContentView()
}

struct TranslationHeaderView: View {
    @Binding var sourceLanguage: Locale.Language?
    @Binding var destinationSelection: TranslationTargetSelection?

    let sourceLanguages: [Locale.Language]
    let targetLanguages: [Locale.Language]
    let isTranslating: Bool
    let canTranslate: Bool
    let languageName: (Locale.Language) -> String?
    let translate: () -> Void

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

            Button("Translate", systemImage: "translate") {
                translate()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("t", modifiers: .command)
            .disabled(!canTranslate)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct TranslationProgressView: View {
    let status: String
    let progressValue: Double
    let completedUnits: Int
    let totalUnits: Int
    let translatedStrings: Int
    let stringsToTranslate: Int
    let completedLanguages: Int
    let totalLanguages: Int
    let elapsedTime: String
    let estimatedTimeRemaining: String
    let isTranslating: Bool
    let didFinishTranslation: Bool
    let cancelTranslation: () -> Void

    private var progressText: String {
        guard totalUnits > 0 else {
            return "Ready"
        }

        return "\(Int((progressValue * 100).rounded()))%"
    }

    private var stringsText: String {
        guard stringsToTranslate > 0 else {
            return "No file"
        }

        return "\(translatedStrings)/\(stringsToTranslate)"
    }

    private var languagesText: String {
        guard totalLanguages > 0 else {
            return "No target"
        }

        return "\(completedLanguages)/\(totalLanguages)"
    }

    private var totalText: String {
        guard totalUnits > 0 else {
            return "No work"
        }

        return "\(completedUnits)/\(totalUnits)"
    }

    private var progressTint: Color {
        if didFinishTranslation {
            return .green
        }

        return isTranslating ? .accentColor : .secondary
    }

    private var metricColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: 110), spacing: 10),
            count: 5
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Progress")
                        .font(.headline)
                    Text(status)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isTranslating {
                    Button("Stop", systemImage: "stop.fill", role: .cancel) {
                        cancelTranslation()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .keyboardShortcut(.cancelAction)
                }

                Text(progressText)
                    .font(.title2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(progressTint)
            }

            ProgressView(value: progressValue, total: 1)
                .progressViewStyle(.linear)
                .tint(progressTint)

            LazyVGrid(
                columns: metricColumns,
                spacing: 10
            ) {
                ProgressMetricView(
                    title: "Strings",
                    value: stringsText,
                    systemImage: "text.quote"
                )

                ProgressMetricView(
                    title: "Languages",
                    value: languagesText,
                    systemImage: "globe"
                )

                ProgressMetricView(
                    title: "Total",
                    value: totalText,
                    systemImage: "checkmark.circle"
                )

                ProgressMetricView(
                    title: "Elapsed",
                    value: elapsedTime,
                    systemImage: "timer"
                )

                ProgressMetricView(
                    title: "ETA",
                    value: estimatedTimeRemaining,
                    systemImage: "clock"
                )
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                SiriProgressGlowView(isActive: isTranslating)

                RoundedRectangle(cornerRadius: 8)
                    .fill(.background)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary)
        }
    }
}

struct SiriProgressGlowView: View {
    let isActive: Bool

    @State private var rotateGlow = false
    @State private var pulseGlow = false

    private var glowOpacity: Double {
        isActive ? 0.9 : 0.28
    }

    private var glowScale: CGFloat {
        if !isActive {
            return 1
        }

        return pulseGlow ? 1.035 : 0.98
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: [
                        .cyan,
                        .blue,
                        .purple,
                        .pink,
                        .orange,
                        .cyan
                    ]),
                    center: .center,
                    angle: rotateGlow ? .degrees(360) : .zero
                ),
                lineWidth: isActive ? 3 : 1.5
            )
            .scaleEffect(glowScale)
            .blur(radius: isActive ? 12 : 8)
            .opacity(glowOpacity)
            .onAppear {
                withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
                    rotateGlow = true
                }

                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    pulseGlow = true
                }
            }
            .accessibilityHidden(true)
    }
}

struct ProgressMetricView: View {
    let title: LocalizedStringKey
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(value)
                    .font(.callout.monospacedDigit().weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 58, maxHeight: 58, alignment: .leading)
        .background(.quinary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct TranslationStringsListView: View {
    let stringsToTranslate: [String]
    let translatedStrings: [String: String]
    let currentTranslation: String?
    let openFilePicker: () -> Void

    var body: some View {
        ScrollViewReader { scrollProxy in
            List {
                if stringsToTranslate.isEmpty {
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
                } else {
                    ForEach(stringsToTranslate, id: \.self) { string in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(string)
                                .font(.body.weight(.medium))

                            if let translation = translatedStrings[string], !translation.isEmpty {
                                Text(translation)
                                    .foregroundStyle(.secondary)
                            } else {
                                Label("Waiting for translation", systemImage: "hourglass")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 4)
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
    }
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

            Spacer()

            Button("Open", systemImage: "square.and.arrow.down") {
                openFilePicker()
            }
            .keyboardShortcut("o", modifiers: .command)
            .disabled(isTranslating)

            Button("Save", systemImage: "square.and.arrow.up") {
                save()
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(!canSave)
        }
    }
}
