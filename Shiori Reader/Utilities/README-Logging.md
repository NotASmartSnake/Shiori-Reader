# Shiori Reader Logging System

This file documents the logging system implemented for Shiori Reader to help with debugging during development while ensuring logs are stripped out for App Store submission.

## Overview

The logging system consists of:
1. A `Logger` utility class that handles all logging operations
2. Build configuration settings that automatically disable logs in release builds
3. Helper utilities to manage debug vs release behaviors

## How to Use Logger

### Basic Usage

Replace all `print()` statements with the appropriate Logger level call:

```swift
// Instead of:
print("DEBUG: Something happened")

// Use:
Logger.debug(category: "CategoryName", "Something happened")
```

Available log levels (in order of severity):
- `debug` - For detailed debugging information
- `info` - For general information
- `warning` - For potential issues that don't prevent normal operation
- `error` - For errors that might cause problems (these appear even in release builds)
- `jsLog` - For logs coming from JavaScript
- `jsConsole` - For console messages from JavaScript

### Benefits

1. Logs are automatically disabled in release builds (App Store submission)
2. Each log includes file name and line number for better debugging
3. Category-based filtering makes it easier to find relevant logs
4. Consistent formatting across the app

## Implementation Details

### In Debug Builds

- All log levels are shown
- File and line information is included
- Categories help organize logs by component

### In Release Builds

- Most logs are completely stripped out at compile time (zero overhead)
- Only `error` level logs are preserved for critical issues

## Adding Logging to New Files

1. Import Foundation (Logger is accessible through Foundation)
2. Use the appropriate log level method
3. Provide a meaningful category name

Example:

```swift
import Foundation

class MyClass {
    func doSomething() {
        Logger.debug(category: "MyComponent", "Starting operation")
        
        // Do work...
        
        if problemDetected {
            Logger.warning(category: "MyComponent", "Problem detected: \(details)")
        }
        
        // More work...
        
        if fatalError {
            Logger.error(category: "MyComponent", "Fatal error: \(errorDetails)")
        }
        
        Logger.info(category: "MyComponent", "Operation completed")
    }
}
```

## Controlling Log Behavior

The `BuildConfig` class provides additional control over logging:

```swift
// To temporarily disable logs in debug builds:
Logger.isEnabled = false

// To check if running in debug mode:
if BuildConfig.isDebugMode {
    // Do something only in debug builds
}

// To check if verbose logging is enabled:
if BuildConfig.FeatureFlag.enableVerboseLogging {
    // Do extra detailed logging
}
```
