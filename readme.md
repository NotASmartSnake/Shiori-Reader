# Shiori Reader 📖

Shiori Reader is an iOS application designed for Japanese language learners to read EPUB books with powerful dictionary and vocabulary learning features.

## 🌟 Features

### 📚 Advanced Reading Experience
- Seamless EPUB book rendering using Readium
- Customizable reading preferences (font, size, reading direction)
- Pagination and scroll modes
- Progress tracking

### 📖 Japanese Language Learning Tools
- One-tap word lookup
- Comprehensive dictionary integration
- Support for kanji, furigana, and complex Japanese text
- Context-aware word selection

### 🧠 Vocabulary Management
- Save words directly from the reader
- Export words to Anki for spaced repetition learning
- Saved words management with tagging and filtering

### 🔍 Advanced Dictionary Functionality
- Deinflection support for verb and adjective conjugations
- Multiple dictionary lookup strategies
- Comprehensive word information display

## 🛠 Technologies

- Swift
- SwiftUI
- Readium (EPUB rendering)
- MeCab (Japanese text tokenization)
- SQLite (dictionary backend)
- Anki Integration

## 🚀 Getting Started

### Prerequisites
- Xcode 15+
- iOS 17+
- AnkiMobile (optional, for Anki export)

### Installation
1. Clone the repository
2. Open `Shiori Reader.xcodeproj` in Xcode
3. Install dependencies via Swift Package Manager
4. Build and run on simulator or device

## 🔧 Configuration

### Dictionary
- Pre-configured JMdict database
- Deinflection rules for comprehensive Japanese word lookup

### Anki Integration
- Configure note types and field mappings
- Customize export settings

## 📦 Dependencies
- Readium Swift Toolkit
- MeCab Swift
- SQLite.swift
- CryptoSwift
- Zip

## 📄 License
This project is licensed under the MIT License. See the LICENSE file for details.
- Permissions: ✅ Commercial use, ✅ Modification, ✅ Distribution, ✅ Private use
- Limitations: ❌ Liability, ❌ Warranty

## 👥 Credits
Created by Russell Graviet

## 🎯 Roadmap
- [ ] Enhanced dictionary caching
- [ ] More theme options
- [ ] Cloud sync for saved words
- [ ] Machine translation integration
- [ ] Improved Anki sync

## 🛡 Disclaimer
This app is for educational purposes and to support Japanese language learning.

## 👤 Privacy Policy
Shiori Reader does not collect, transmit, or share any user data. All data including imported books, reading progress, bookmarks, and saved vocabulary words are stored locally on your device and never leave it.

The only external communication occurs when using the optional Anki integration feature, which uses iOS URL schemes to communicate with the Anki app on the same device (if installed).

No analytics, tracking, or telemetry data is collected.

Last updated: 4/23/2025
