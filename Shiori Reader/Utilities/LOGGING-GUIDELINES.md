# Shiori Reader Logging Guidelines

This document provides guidelines for using the Logger system in Shiori Reader to ensure consistency across the codebase and to help prepare for App Store submission.

## Converting Print Statements to Logger Calls

When updating your code, follow these patterns to replace print statements with appropriate Logger calls:

### Debug Statements

```swift
// Old style:
print("DEBUG [Component]: Your debug message")

// New style:
Logger.debug(category: "Component", "Your debug message")
```

### Info Statements

```swift
// Old style:
print("INFO [Component]: Your info message")

// New style:
Logger.info(category: "Component", "Your info message")
```

### Warning Statements

```swift
// Old style:
print("WARN [Component]: Your warning message")
// or
print("WARNING [Component]: Your warning message")

// New style:
Logger.warning(category: "Component", "Your warning message")
```

### Error Statements 

```swift
// Old style:
print("ERROR [Component]: Your error message")

// New style:
Logger.error(category: "Component", "Your error message")
```

### JavaScript Logs

```swift
// Old style:
print("JS LOG [Component]: Your JavaScript log message")

// New style:
Logger.jsLog(category: "Component", "Your JavaScript log message")
```

### JavaScript Console Output

```swift
// Old style:
print("JS CONSOLE [Type]: Your console message")

// New style:
Logger.jsConsole(type: "Type", "Your console message")
```

## Logger Categories

Use consistent category names throughout the codebase:

- Component/class name (e.g., "WordTapHandler", "ReaderViewModel")
- Feature area (e.g., "Import", "Reader", "Dictionary")
- Cross-cutting concerns (e.g., "Network", "Storage", "UI")

## Search Patterns for Finding Print Statements

Use these search patterns to locate remaining print statements in your codebase:

- `print("DEBUG`
- `print("INFO`
- `print("WARN`
- `print("WARNING`
- `print("ERROR`
- `print("JS LOG`
- `print("JS CONSOLE`

## Testing Logger Behavior

1. In DEBUG builds, all logs should appear
2. In RELEASE builds (App Store), logs should not appear

You can toggle logging at runtime using:

```swift
// Disable all logging
Logger.isEnabled = false

// Re-enable logging (DEBUG builds only)
Logger.isEnabled = true
```

Use the DebugMenu to toggle logging during development.

## Next Steps for Complete Migration

1. Use search patterns above to find remaining print statements
2. Convert each statement to appropriate Logger calls
3. Ensure proper category names for organizational clarity
4. Test in both Debug and Release configurations
5. Use the DebugMenu to verify runtime toggling works correctly

Remember, Logger calls in release builds add zero overhead to your app's performance, as they are completely stripped out at compile time.
