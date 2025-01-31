import Foundation
import Translation

let stringsToTranslate = [
    "Hello, World!",
    "Goodbye, World!"
]

Task {
    print(await LanguageAvailability().supportedLanguages)
}

// /// Source text for translation
var sourceLanguage: Locale.Language = .init(identifier: "en")

// /// Target language for translation
var targetLanguage: Locale.Language = .init(identifier: "nl")

var configuration: TranslationSession.Configuration? = TranslationSession.Configuration(
    source: sourceLanguage,
    target: targetLanguage
)

do {
    let session = TranslationSession()

    // Perform translation
    let response = try await session.translate("Hello, World!")

    // Update target text
    print(response)
} catch {
    // code to handle error
}

Task {
    // Sleep for a bit to allow the translation to complete
    try? await Task.sleep(nanoseconds: 1_000)
}
