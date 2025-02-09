# xcstrings translator

xcstrings translator is a simple tool to translate `.xcstrings` files, using Apple's Translate framework.
The tool is written in Swift and uses the Apple's Translate framework to translate the `.xcstrings` files.

## Limitations/TODO

- Translate in _all_ supported languages with one button.
- Skip string if it's already translated.
- Skip strings marked with `shouldTranslate: false`.

## Finished

- Input language detection.
- Translate to a specific language.
- Save translated strings to the input file.
- Save translated strings to a new file. (only if _test mode_ is enabled)

## Screenshots

<img width="1012" alt="image" src="https://github.com/user-attachments/assets/f4d1bb94-957c-40a8-a9c0-cb961047454a" />

https://github.com/user-attachments/assets/0aaf99fc-4c60-4775-bd1c-cb977758d65f

## Alternatives

I'm not planning to add support for `Google Translate`, `DeepL`, `Microsoft Translator` or any other (AI) translation service, If you think it should be added, feel welcome to create a pull request.

Alternatives to this tool are (but not limited to):
- [TranslateKit](https://translatekit.app) by [Cihat Gündüz](https://www.fline.dev/about/?ref=wesleydegroot.nl), TranslateKit uses `DeepL`, `Google Translate` and `Microsoft Translator`, it relies on in-app subscriptions.

## Special Thanks

Special thanks to these wonderful people:
- [Zhenyi Tan](https://andadinosaur.com) for his help on a [saving issue](https://mastodon.social/@zhenyi/113969196950076700) which I encountered.
- [Cihat Gündüz](https://www.fline.dev/about) creating [TranslateKit](https://translatekit.app) which gave me an idea how to build the GUI of this application.

## Frameworks/Packages used

Here are the frameworks/packages used in this project:
- [Translation framework](https://developer.apple.com/documentation/translation/) by [Apple](https://apple.com)
- [FilePicker](https://github.com/0xWDG/FilePicker) by [Wesley de Groot](https://wesleydegroot.nl)
- [SwiftExtras](https://github.com/0xWDG/SwiftExtras) by [Wesley de Groot](https://wesleydegroot.nl)

## Contact

🦋 [@0xWDG](https://bsky.app/profile/0xWDG.bsky.social)
🐘 [mastodon.social/@0xWDG](https://mastodon.social/@0xWDG)
🐦 [@0xWDG](https://x.com/0xWDG)
🧵 [@0xWDG](https://www.threads.net/@0xWDG)
🌐 [wesleydegroot.nl](https://wesleydegroot.nl)
🤖 [Discord](https://discordapp.com/users/918438083861573692)

Interested learning more about Swift? [Check out my blog](https://wesleydegroot.nl/blog/).
