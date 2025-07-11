# Yomitan Dictionary Import System

This module adds support for importing Yomitan-formatted dictionaries into Shiori Reader. It allows users to import custom dictionaries in ZIP format and seamlessly integrates them with the existing dictionary lookup system.

## Overview

The import system consists of several components:

- **YomitanSchemas.swift**: Data structures matching the Yomitan dictionary format
- **YomitanDictionaryImporter.swift**: Main importer that processes ZIP files and extracts dictionary data
- **SQLiteYomitanDictionary.swift**: Converts Yomitan data to SQLite databases compatible with your existing DictionaryManager
- **SimpleZipExtractor.swift**: Basic ZIP file extraction utility
- **DictionaryImportManager.swift**: Coordinator that manages the import process and maintains a registry of imported dictionaries
- **DictionaryManager+YomitanImport.swift**: Extension that integrates imported dictionaries with the existing lookup system
- **DictionaryImportTestView.swift**: Test UI for importing and viewing dictionaries

## Features

- Support for Yomitan dictionary format versions 1-3
- ZIP file extraction and validation
- Progress tracking during import
- SQLite database creation compatible with existing DictionaryManager
- Integration with existing dictionary lookup and deinflection
- Registry management for imported dictionaries
- Test UI for easy testing

## Supported Yomitan Format Features

### Currently Supported
- Term banks (term_bank_*.json) - vocabulary entries with definitions
- Tag banks (tag_bank_*.json) - part-of-speech and other metadata tags
- Term meta banks (term_meta_bank_*.json) - frequency and other metadata
- Index file validation
- Version 1 and 3 formats
- Basic glossary structures (text and structured content)

### Not Yet Implemented
- Kanji banks (for kanji dictionary entries)
- Complex structured content (images, advanced formatting)
- Frequency data integration with existing BCCWJ system
- Pitch accent data from term meta

## Usage

### Basic Import

```swift
// Import a dictionary from a ZIP file
let importManager = DictionaryImportManager.shared

await importManager.importDictionary(from: zipFileURL)

// Check for errors
if let error = importManager.lastImportError {
    print("Import failed: \(error)")
} else {
    print("Import successful!")
}
```

### Using Imported Dictionaries

Once imported, dictionaries are automatically integrated with the existing DictionaryManager:

```swift
// Setup imported dictionaries on app launch
DictionaryManager.shared.setupImportedDictionaries()

// Use enhanced lookup that includes imported dictionaries
let results = DictionaryManager.shared.lookupWithImportedDictionaries(word: "猫")

// Or use with deinflection
let resultsWithDeinflection = DictionaryManager.shared.lookupWithDeinflectionAndImported(word: "食べる")
```

### Managing Imported Dictionaries

```swift
// Get list of imported dictionaries
let importedDictionaries = DictionaryImportManager.shared.getImportedDictionaries()

// Delete a dictionary
try DictionaryImportManager.shared.deleteImportedDictionary(dictionary)
```

## Integration with Existing Code

### App Launch
Add this to your app initialization:

```swift
// In your AppDelegate or main app initialization
DictionaryManager.shared.setupImportedDictionaries()
```

### Dictionary Lookup
Replace existing dictionary lookups with the enhanced versions:

```swift
// Old: 
let results = DictionaryManager.shared.lookupWithDeinflection(word: word)

// New:
let results = DictionaryManager.shared.lookupWithDeinflectionAndImported(word: word)
```

### Settings Integration
You can extend your dictionary settings to include imported dictionaries by modifying the `getEnabledDictionaries()` method in DictionaryManager.

## Testing

Use the provided `DictionaryImportTestView` to test the import functionality:

```swift
// Present the test view
let testView = DictionaryImportTestView()
```

The test view provides:
- File picker for selecting ZIP files
- Progress monitoring during import
- Error display
- List of imported dictionaries
- Import status feedback

## Limitations and Future Improvements

### Current Limitations
1. **ZIP Extraction**: Uses a basic ZIP extractor. For production, consider using ZIPFoundation for better compatibility
2. **Memory Usage**: Large dictionaries may consume significant memory during import
3. **Error Recovery**: Limited error recovery for partially corrupted files
4. **Validation**: Basic validation - doesn't catch all possible format issues

### Suggested Improvements
1. **ZIPFoundation Integration**: Replace SimpleZipExtractor with ZIPFoundation for better ZIP support
2. **Streaming Import**: Process large files in chunks to reduce memory usage
3. **Background Import**: Move import process to background threads
4. **Enhanced Validation**: Add more comprehensive validation of dictionary data
5. **Settings Integration**: Full integration with dictionary settings UI
6. **Kanji Support**: Add support for kanji banks
7. **Advanced Features**: Support for images, audio, and complex structured content

## File Structure

```
Features/DictionaryImport/
├── YomitanSchemas.swift              # Data structures for Yomitan format
├── YomitanDictionaryImporter.swift   # Main import logic
├── SQLiteYomitanDictionary.swift     # Database creation
├── SimpleZipExtractor.swift          # ZIP file extraction
├── DictionaryImportManager.swift     # Import coordination
├── DictionaryManager+YomitanImport.swift  # Integration extension
└── DictionaryImportTestView.swift    # Test UI
```

## Error Handling

The system provides comprehensive error handling:

- **YomitanImportError.invalidZipFile**: ZIP file is corrupted or invalid
- **YomitanImportError.missingIndexFile**: No index.json found
- **YomitanImportError.invalidIndexFile**: index.json is malformed
- **YomitanImportError.unsupportedVersion**: Dictionary version not supported
- **YomitanImportError.invalidJSONFile**: Data files are malformed
- **YomitanImportError.databaseCreationFailed**: SQLite database creation failed
- **YomitanImportError.importCancelled**: User cancelled the import

## Database Schema

Imported dictionaries use the same schema as your existing dictionaries:

```sql
CREATE TABLE terms (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    expression TEXT NOT NULL,
    reading TEXT NOT NULL,
    term_tags TEXT,
    score TEXT,
    rules TEXT,
    definitions TEXT NOT NULL,
    sequence INTEGER,
    popularity TEXT,
    dictionary TEXT NOT NULL
);
```

This ensures seamless integration with your existing lookup code.
