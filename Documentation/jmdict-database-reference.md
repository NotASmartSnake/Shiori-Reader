# JMdict Database Reference for Shiori Reader

This document serves as a reference for the Japanese dictionary database integration in Shiori Reader. It provides the database schema, example entries, lookup patterns, and integration guidelines for the project.

## Database Overview

The dictionary is based on the JMdict (Japanese-Multilingual Dictionary) data converted to SQLite format. It contains Japanese terms with readings, definitions, part-of-speech tags, and other linguistic information.

## Database Schema

### Tables Structure

```sql
-- Terms table: Contains Japanese words and their metadata
CREATE TABLE terms (
    id INTEGER PRIMARY KEY,
    expression TEXT NOT NULL,       -- The Japanese term (kanji, kana, or mixed)
    reading TEXT NOT NULL,          -- How to read/pronounce the term (kana)
    term_tags TEXT,                 -- Part of speech and other grammatical information
    rules TEXT,                     -- Grammar rules or usage notes
    popularity TEXT,                -- Relative popularity of word (double, higher number means more popular)
    sequence INTEGER,               -- Ordering/priority value
    score INTEGER,                  -- Frequency/importance score
    expression_normalized TEXT NOT NULL,  -- Expression with standardized kana
    reading_normalized TEXT NOT NULL,     -- Reading with standardized kana
    UNIQUE(expression, reading)     -- Prevent exact duplicates
);

-- Definitions table: Contains meanings for terms (one-to-many relationship)
CREATE TABLE definitions (
    id INTEGER PRIMARY KEY,
    term_id INTEGER NOT NULL,       -- References the terms table
    definition TEXT NOT NULL,       -- The actual definition text
    FOREIGN KEY (term_id) REFERENCES terms(id)
);

-- Tags table: Dictionary tag metadata
CREATE TABLE tags (
    name TEXT PRIMARY KEY,
    category TEXT,
    notes TEXT,
    score INTEGER
);
```

### Indexes

```sql
-- Indexes for fast lookup
CREATE INDEX idx_terms_expression ON terms(expression);
CREATE INDEX idx_terms_reading ON terms(reading);
CREATE INDEX idx_terms_expression_normalized ON terms(expression_normalized);
CREATE INDEX idx_terms_reading_normalized ON terms(reading_normalized);

-- Special indexes for prefix and suffix search
CREATE INDEX idx_terms_expression_prefix ON terms(expression);
CREATE INDEX idx_terms_reading_prefix ON terms(reading);

-- Index for definitions
CREATE INDEX idx_definitions_term_id ON definitions(term_id);
```

## Example Entries

Here are a few representative entries from the database showing the structure:

### Example 1: Basic noun (明白)

**Terms table row:**
```
id: 1245
expression: "明白"
reading: "めいはく"
term_tags: "adj-na"
rules: ""
popularity: ""
sequence: 1999800
score: null
expression_normalized: "明白"
reading_normalized: "めいはく"
```

**Definitions table rows:**
```
id: 2490
term_id: 1245
definition: "obvious; clear; plain; evident; apparent; explicit; overt"
```

### Example 2: Verb with multiple forms (食べる)

**Terms table row:**
```
id: 5789
expression: "食べる"
reading: "たべる"
term_tags: "v1,vt"
rules: ""
popularity: ""
sequence: 1245600
score: null
expression_normalized: "食べる"
reading_normalized: "たべる"
```

**Definitions table rows:**
```
id: 11578
term_id: 5789
definition: "to eat; to consume; to live on (e.g. a salary); to live off; to feed; to earn a living"
```

### Example 3: Expression with multiple definitions (手を出す)

**Terms table row:**
```
id: 8732
expression: "手を出す"
reading: "てをだす"
term_tags: "exp,v5s"
rules: ""
popularity: ""
sequence: 1687400
score: null
expression_normalized: "手をだす"
reading_normalized: "てをだす"
```

**Definitions table rows:**
```
id: 17464
term_id: 8732
definition: "to reach out for; to stretch out one's hand; to extend one's hand"

id: 17465
term_id: 8732
definition: "to start (work); to set one's hand to; to take part in"

id: 17466
term_id: 8732
definition: "to lay a hand on; to use violence against"

id: 17467
term_id: 8732
definition: "to touch; to fool around with; to mess with; to meddle in"
```

## Dictionary Lookup Patterns

### Basic Word Lookup

```sql
-- Direct lookup by expression (kanji form)
SELECT t.id, t.expression, t.reading, d.definition
FROM terms t
JOIN definitions d ON t.id = d.term_id
WHERE t.expression = ?;

-- Direct lookup by reading (kana form)
SELECT t.id, t.expression, t.reading, d.definition
FROM terms t
JOIN definitions d ON t.id = d.term_id
WHERE t.reading = ?;
```

### Fuzzy Matching

```sql
-- Prefix matching (for input method suggestions)
SELECT t.id, t.expression, t.reading, d.definition
FROM terms t
JOIN definitions d ON t.id = d.term_id
WHERE t.expression LIKE ? || '%' OR t.reading LIKE ? || '%'
ORDER BY t.sequence
LIMIT 20;

-- Suffix matching (for compounds)
SELECT t.id, t.expression, t.reading, d.definition
FROM terms t
JOIN definitions d ON t.id = d.term_id
WHERE t.expression LIKE '%' || ? OR t.reading LIKE '%' || ?
ORDER BY t.sequence
LIMIT 20;
```

### Context-Aware Lookup for Inflected Forms

For verbs and adjectives that might be inflected in text, you may need more complex pattern matching or a separate conjugation engine. This would typically be implemented in application code rather than pure SQL.

## Integration with Shiori Reader

### Core Use Cases

1. **Single-Word Lookup**: 
   - Triggered by tapping on a word in the EPUB reader
   - Shows definition popup/card with readings and meanings
   - Option to save to vocabulary list

2. **Batch Word Processing**:
   - Analyze text to identify known/unknown words
   - Suggest words to learn based on frequency
   - Generate vocabulary lists from current reading material

3. **Saved Word Management**:
   - Track and review saved words
   - Export to spaced repetition systems (like Anki)

### Integration Points

#### 1. Text Selection Handler

```swift
// Pseudocode for word lookup on tap
func handleTextTap(word: String) {
    let lookupResults = dictionaryManager.lookup(word: word)
    if !lookupResults.isEmpty {
        showDefinitionPopup(entries: lookupResults)
    }
}
```

#### 2. Dictionary Manager

```swift
// Core lookup functionality
class DictionaryManager {
    private let database: SQLiteDatabase
    
    init(databasePath: String) {
        self.database = SQLiteDatabase(path: databasePath)
    }
    
    func lookup(word: String) -> [DictionaryEntry] {
        // Query database for word
        let query = """
            SELECT t.id, t.expression, t.reading, d.definition
            FROM terms t
            JOIN definitions d ON t.id = d.term_id
            WHERE t.expression = ? OR t.reading = ?
            ORDER BY t.sequence, d.id
        """
        
        return database.execute(query: query, parameters: [word, word])
    }
    
    // Additional methods for batch lookups, frequency analysis, etc.
}
```

#### 3. Saved Words Repository

```swift
// Managing user's saved/studied words
class SavedWordsRepository {
    private let database: SQLiteDatabase
    
    func saveWord(termId: Int, expression: String, reading: String, definition: String) {
        // Store in user's saved words
    }
    
    func getSavedWords() -> [SavedWord] {
        // Retrieve user's saved words
    }
    
    func exportToAnki() -> AnkiDeck {
        // Generate Anki-compatible export
    }
}
```

## Performance Considerations

1. **Database Size**: The full JMdict database can be large (~50-100MB). Consider:
   - Lazy loading of definitions
   - Background loading of the database
   - Possibly a reduced version for mobile

2. **Query Optimization**:
   - Use prepared statements for repeated queries
   - Consider in-memory caching for frequently accessed terms
   - Use appropriate indexes as defined in the schema

3. **UI Responsiveness**:
   - Perform lookups in background threads
   - Show loading indicators for slower operations
   - Pre-cache definitions for visible text when possible

## Future Extensions

1. **Pitch Accent Data**: Add pronunciation guides with pitch accent information
2. **Example Sentences**: Link to example usage from literature or corpora
3. **Frequency Information**: Mark words by frequency of use in native materials
4. **Custom User Notes**: Allow users to add their own notes to dictionary entries
5. **Multiple Dictionaries**: Support loading specialized dictionaries (medical, technical, slang, etc.)

---

This reference document provides the core information needed to work with the JMdict database in the Shiori Reader project. It can be updated as the integration evolves.
