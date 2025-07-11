# Dictionary Import Implementation Roadmap

## Current Status ✅
- **Path resolution fixed** - Dictionaries persist across app restarts
- **Search integration working** - Imported dictionaries appear in search results
- **Debug tools complete** - Can test and troubleshoot imports

## Implementation Plan

### Phase 1: Cleanup & Refactoring 🧹

#### Remove Test/Debug Files
- [ ] Remove `DictionaryImportTestView.swift` (not used in production)
- [ ] Remove `DictionaryImportTestApp.swift` (was for testing only)
- [ ] Remove `IntegrationExample.swift` (documentation only)
- [ ] Remove `Debug/` folder contents:
  - [ ] `DictionaryImportDebugView.swift`
  - [ ] `DictionaryImportDebugger.swift` 
  - [ ] `DictionaryImportTestRunner.swift`
- [ ] Remove debug logging from production code
- [ ] Keep only: `DictionaryImportManager.swift`, `DictionaryManager+YomitanImport.swift`, core import classes

#### Method Naming Refactor
- [ ] Replace `lookupWithDeinflection()` method with enhanced version that includes imported dictionaries
- [ ] Remove `lookupWithDeinflectionAndImported()` - merge logic into original method
- [ ] Remove `lookupWithImportedDictionaries()` - merge into main lookup
- [ ] Keep same method signatures, just enhance internal logic
- [ ] Update all existing callsites automatically (no API changes needed)

### Phase 2: Settings UI Integration 🔧

#### Dictionary Settings View
- [ ] Add "Import Dictionary" button to existing Dictionary Settings
- [ ] Present system file picker for ZIP files (not test view)
- [ ] Show import progress bar during dictionary import
- [ ] Display import success/error messages

#### Dictionary List Integration  
- [ ] Modify existing dictionary list in `DictionaryPopupView` to include imported dictionaries
- [ ] Use same row model as built-in dictionaries
- [ ] Assign unique colors to imported dictionaries (extend existing color system)
- [ ] No visual distinction between built-in vs imported - treat all as equal

#### Dictionary Management
- [ ] Show imported dictionaries in same list as built-in ones
- [ ] Add delete functionality for imported dictionaries (swipe to delete or edit mode)
- [ ] Show dictionary metadata (name, entry count) in same format as built-in

### Phase 3: Search Method Integration 🔍

#### Core Search Updates
- [ ] Update `DictionaryManager.lookup()` to include imported dictionaries by default
- [ ] Update `DictionaryManager.lookupWithDeinflection()` to include imported dictionaries
- [ ] Remove separate imported dictionary methods - merge into core methods
- [ ] Maintain same performance characteristics and result limits

#### Search Entry Points Audit
- [ ] **SearchViewModel**: Verify uses updated methods
- [ ] **ReaderViewModel**: Update any direct lookup calls
- [ ] **Any other search locations**: Find and update remaining lookup calls

### Phase 4: App Integration 📱

#### Startup Integration
- [ ] Ensure `setupImportedDictionaries()` called on app launch
- [ ] Handle startup errors gracefully
- [ ] No loading indicators needed (fast enough with current approach)

#### Storage & Persistence
- [ ] Verify imported dictionaries persist across app restarts ✅
- [ ] Handle edge cases for missing/corrupted files
- [ ] Basic storage space awareness

### Phase 5: Polish & Testing 💎

#### Error Handling
- [ ] Improve import error messages for users
- [ ] Handle file access permissions gracefully
- [ ] Recovery from failed imports

#### Code Quality
- [ ] Remove debug print statements from production code
- [ ] Add proper error handling throughout
- [ ] Code review and cleanup

## Files to Keep (Core Implementation)

### Essential Files
- `DictionaryImportManager.swift` - Core import logic
- `DictionaryManager+YomitanImport.swift` - Integration with existing DictionaryManager
- `YomitanDictionaryImporter.swift` - ZIP processing and database creation
- `SQLiteYomitanDictionary.swift` - Database schema and creation
- `YomitanSchemas.swift` - Data structures for Yomitan format
- `SimpleZipExtractor.swift` - ZIP file handling

### Optional Utility Files
- `DictionaryDatabaseInspector.swift` - Keep for debugging/support
- `README.md` - Documentation
- `README_DEBUGGING.md` - Support documentation

## Implementation Notes

### UI/UX Approach
- **File Import**: Use native iOS file picker, not custom UI
- **Progress**: Simple progress bar in settings during import
- **Dictionary Display**: Seamless integration with existing dictionary list
- **No Special Handling**: Imported dictionaries are first-class citizens

### Technical Approach
- **Method Replacement**: Enhance existing methods rather than adding new ones
- **Backward Compatibility**: No API changes needed
- **Performance**: Leverage existing search limits and optimizations
- **Integration**: Minimal changes to existing codebase

### Success Criteria
1. Users can import Yomitan dictionaries via file picker
2. Imported dictionaries appear in search results seamlessly
3. Dictionary management works through existing UI patterns
4. No performance degradation from current implementation
5. Clean, maintainable codebase without debug/test artifacts

## Priority Order

1. **Phase 1** (Cleanup) - Remove test files, refactor method names
2. **Phase 2** (Settings) - Add import button and progress UI
3. **Phase 3** (Search Integration) - Update core lookup methods
4. **Phase 4** (App Integration) - Ensure startup and persistence work
5. **Phase 5** (Polish) - Error handling and cleanup

## Out of Scope (Future Phases)
- Dictionary updates/versioning
- Batch imports
- Cloud storage integration
- Advanced performance optimizations
- Dictionary compatibility checking
- iCloud sync for imported dictionaries