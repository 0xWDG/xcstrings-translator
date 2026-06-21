# XCStrings Translator

XCStrings Translator is a macOS app for translating Xcode String Catalog
(`.xcstrings`) files with Apple's on-device Translation framework.

It is built for developers who want to quickly fill or refresh localization
entries without sending their string catalogs to a third-party translation
service.

## Features

- Open `.xcstrings` files from the app, Finder, or the macOS Open With menu.
- Translate to one target language or all system-supported target languages.
- Only shows language pairs that are available through Apple's Translation framework.
- Skips existing translations by default.
- Skips entries marked with `"shouldTranslate": false`.
- Translate dropdown option to overwrite all existing translations with fresh translations.
- Preserves regional language identifiers such as `pt-BR` and script identifiers such as `zh-Hant`.
- Preserves existing localization metadata where possible.
- Saves completed-language checkpoints during translation to reduce progress loss after a crash.
- Supports manual export/save, partial saving after cancellation, and optional automatic saving.
- Shows progress, elapsed time, ETA, current item, completed languages, and Dock progress.
- Prompts after the first translation run to set the app as the default `.xcstrings` opener.
- Includes accessibility labels, hints, and identifiers for the main UI controls.

## Requirements

- macOS 15.2 or newer.
- Xcode 16.2 or newer for development.
- Apple Translation framework language support installed or available on the Mac.

The app uses Apple's Translation framework, so available source/target pairs depend
on the current system.

## Usage

1. Open an `.xcstrings` file.
2. Choose the source language.
3. Choose a target language, or keep the default `All Available Languages`.
4. Click `Translate`.
5. Save the finished or partially finished catalog.

To replace existing translations, open the dropdown next to `Translate` and choose
`Overwrite All Translations`.

## Settings

The Settings window includes:

- Default target language.
- Translation state saved into the catalog: `translated` or `needs_review`.
- Skip already translated entries.
- Automatically save completed-language checkpoints.
- Test Mode, which prevents overwriting the original catalog.
- Make XCStrings Translator the default app for `.xcstrings` files.

## Screenshots

<img width="1012" alt="XCStrings Translator main window" src="https://github.com/user-attachments/assets/f4d1bb94-957c-40a8-a9c0-cb961047454a" />

https://github.com/user-attachments/assets/0aaf99fc-4c60-4775-bd1c-cb977758d65f

## Development

Open the project in Xcode:

```sh
open "XCStrings Translator.xcodeproj"
```

Run checks from the command line:

```sh
swiftlint lint --quiet
xcodebuild test -project "XCStrings Translator.xcodeproj" -scheme "XCStrings Translator" -destination "platform=macOS"
```

## Notes

XCStrings Translator intentionally uses Apple's Translation framework only. There
are no plans to add Google Translate, DeepL, Microsoft Translator, or other
third-party/AI translation services by default.

Pull requests for alternative translation services are welcome if they are
implemented cleanly and remain optional.

## Alternatives

- [TranslateKit](https://translatekit.app) by [Cihat Gündüz](https://www.fline.dev/about/?ref=wesleydegroot.nl) uses DeepL, Google Translate, and Microsoft Translator, and relies on in-app subscriptions.

## Special Thanks

- [Zhenyi Tan](https://andadinosaur.com) for help with a [saving issue](https://mastodon.social/@zhenyi/113969196950076700).
- [Cihat Gündüz](https://www.fline.dev/about) for [TranslateKit](https://translatekit.app), which helped inspire the GUI direction.

## Frameworks And Packages

- [Translation framework](https://developer.apple.com/documentation/translation/) by [Apple](https://apple.com)
- [FilePicker](https://github.com/0xWDG/FilePicker) by [Wesley de Groot](https://wesleydegroot.nl)
- [SwiftExtras](https://github.com/0xWDG/SwiftExtras) by [Wesley de Groot](https://wesleydegroot.nl)
- [OSLogViewer](https://github.com/0xWDG/OSLogViewer) by [Wesley de Groot](https://wesleydegroot.nl)

## Contact

- [@0xWDG on Bluesky](https://bsky.app/profile/0xWDG.bsky.social)
- [@0xWDG on Mastodon](https://mastodon.social/@0xWDG)
- [@0xWDG on X](https://x.com/0xWDG)
- [@0xWDG on Threads](https://www.threads.net/@0xWDG)
- [wesleydegroot.nl](https://wesleydegroot.nl)
- [Discord](https://discordapp.com/users/918438083861573692)

Interested in learning more about Swift? [Check out my blog](https://wesleydegroot.nl/blog/).
