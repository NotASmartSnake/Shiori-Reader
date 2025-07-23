# Shiori Reader

**[Download on the App Store](https://apps.apple.com/us/app/shiori-reader/id6744979827)**

Shiori Reader is an iOS application designed for Japanese language learners to read EPUB books with powerful dictionary and vocabulary learning features.

**Get the app from the App Store for the best experience!** The App Store version includes all features and regular updates.

## Screenshots

<p align="center">
  <img src="Images/library_view.PNG" width="250" alt="Library View" />
  <img src="Images/dictionary_lookup.PNG" width="250" alt="Dictionary Lookup" />
  <img src="Images/saved_words.PNG" width="250" alt="Saved Words" />
</p>

<p align="center">
  <img src="Images/definition_popup.PNG" width="250" alt="Dictionary Popup" />
  <img src="Images/definition_popup_card.PNG" width="250" alt="Dictionary Card" />
  <img src="Images/definition_selection.PNG" width="250" alt="Word Selection" />
</p>

## Features

### Advanced Reading Experience

- Seamless EPUB book rendering using Readium
- Minimal, elegant UI designed for distraction-free reading with clean typography and intuitive controls
- Customizable reading preferences (font, size, background and font colors, dictionary popup appearance)
- Pagination and scroll modes
- Progress tracking and bookmark functionality
- Context menu in dictionary popup to quickly search adjacent words

### Japanese Language Learning Tools

- One-tap, instant word lookups
- Comprehensive dictionary integration with built-in dictionaries (JMdict (Japanese-English bilingual dictionary), 旺文社国語辞典 (Japanese-Japanese monolingual dictionary), BCCWJ Frequency Data, Kanjium Pitch Accents)
- Import functionality for Yomitan-formatted dictionaries
- Support for kanji, furigana, pitch accent, and complex Japanese text
- Context-aware word selection

### Vocabulary Management

- Save words directly from the reader
- Export words to Anki for spaced repetition learning
- Select specific definitions to send to Anki for optimized cards
- Saved words management with tagging and filtering

### Advanced Dictionary Functionality

- Deinflection support for complex verb and adjective conjugations
- Multiple dictionary lookup strategies
- Optimized dictionary searches for low latency

## Technologies

- Swift
- SwiftUI
- Readium (EPUB rendering)
- MeCab (Japanese text tokenization)
- SQLite (dictionary backend)
- Anki Integration

## Issues & Support

If you run into a bug or have a feature request, feel free to open an issue!

- [Submit an issue here](https://github.com/russgrav/Shiori-Reader/issues)

- Before submitting, please:

  - Check if the issue has already been reported

  - Include details like your device, iOS version, and steps to reproduce (if it’s a bug)

If you're not sure whether something is a bug or a question, it's totally okay — just open an issue and tag it appropriately!

## Dependencies

- Readium Swift Toolkit
- MeCab Swift
- SQLite.swift
- CryptoSwift
- Zip

## License

This project is licensed under the MIT License. See the LICENSE file for details.

- Permissions: ✅ Commercial use, ✅ Modification, ✅ Distribution, ✅ Private use
- Limitations: ❌ Liability, ❌ Warranty

## Credits

Created by Russell Graviet

## Disclaimer

This app is for educational purposes and to support Japanese language learning.

## Privacy Policy

Shiori Reader does not collect, transmit, or share any user data. All data including imported books, reading progress, bookmarks, and saved vocabulary words are stored locally on your device and never leave it.

The only external communication occurs when using the optional Anki integration feature, which uses iOS URL schemes to communicate with the Anki app on the same device (if installed).

No analytics, tracking, or telemetry data is collected.

Last updated: 4/23/2025
