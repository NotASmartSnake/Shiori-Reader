//
//  Logger.swift
//  Shiori Reader
//
//  Created on 4/18/25.
//

import Foundation

/// A logging utility for Shiori Reader that allows for debug-only logging
enum Logger {
    /// Log levels in order of increasing severity
    enum Level: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case jsLog = "JS LOG"
        case jsConsole = "JS CONSOLE"
    }
    
    /// Whether or not logging is enabled
    /// This will be automatically set to false for release builds
    #if DEBUG
    static var isEnabled = true
    #else
    static var isEnabled = false
    #endif
    
    /// Log a message with specified level and category
    /// - Parameters:
    ///   - level: The severity level of the log
    ///   - category: The category/component that is logging
    ///   - message: The message to log
    ///   - file: The file the log originated from (auto-filled)
    ///   - function: The function the log originated from (auto-filled)
    ///   - line: The line the log originated from (auto-filled)
    static func log(
        _ level: Level,
        category: String,
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        #if DEBUG
        if isEnabled {
            let fileName = URL(fileURLWithPath: file).lastPathComponent
            print("\(level.rawValue) [\(category)]: \(message()) (\(fileName):\(line))")
        }
        #endif
    }
    
    /// Log a debug message
    static func debug(category: String, _ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, category: category, message(), file: file, function: function, line: line)
    }
    
    /// Log an info message
    static func info(category: String, _ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, category: category, message(), file: file, function: function, line: line)
    }
    
    /// Log a warning message
    static func warning(category: String, _ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, category: category, message(), file: file, function: function, line: line)
    }
    
    /// Log an error message - these always appear even in release builds
    static func error(category: String, _ message: @autoclosure () -> String, file: String = #file, function: String = #function, line: Int = #line) {
        // Errors are always logged, even in release builds
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        print("ERROR [\(category)]: \(message()) (\(fileName):\(line))")
    }
    
    /// Log JavaScript log messages
    static func jsLog(category: String, _ message: @autoclosure () -> String) {
        #if DEBUG
        if isEnabled {
            print("JS LOG [\(category)]: \(message())")
        }
        #endif
    }
    
    /// Log JavaScript console messages
    static func jsConsole(type: String, _ message: @autoclosure () -> String) {
        #if DEBUG
        if isEnabled {
            print("JS CONSOLE [\(type)]: \(message())")
        }
        #endif
    }
}
