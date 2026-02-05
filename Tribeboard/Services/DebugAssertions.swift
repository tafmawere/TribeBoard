//
//  DebugAssertions.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/04.
//

import Foundation

/// Debug assertion utility functions for safe debugging across build configurations
/// Provides logging integration with DebugStateManager without crashing in any build

/// Main debug assertion function with DEBUG/Release mode handling
/// - Parameters:
///   - condition: The condition to assert
///   - message: The assertion message
///   - file: Source file (automatically filled)
///   - line: Source line (automatically filled)
func debugAssert(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
    if !condition {
        // Always log to DebugStateManager for overlay display
        Task { @MainActor in
            DebugStateManager.shared.logDebugAssertion(message, file: file, line: line)
        }
        
        #if DEBUG
        // In DEBUG builds, provide detailed logging
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        print("DEBUG ASSERTION FAILED: \(message) at \(fileName):\(line)")
        #else
        // In Release builds, use safe fallback logging
        print("SAFE FALLBACK: \(message)")
        #endif
    }
}

/// Convenience function for logging debug information without assertion
/// - Parameters:
///   - message: The debug message
///   - file: Source file (automatically filled)
///   - line: Source line (automatically filled)
func debugLog(_ message: String, file: String = #file, line: Int = #line) {
    Task { @MainActor in
        DebugStateManager.shared.logDebugAssertion("LOG: \(message)", file: file, line: line)
    }
    
    #if DEBUG
    let fileName = URL(fileURLWithPath: file).lastPathComponent
    print("DEBUG LOG: \(message) at \(fileName):\(line)")
    #else
    print("LOG: \(message)")
    #endif
}

/// Assert that a value is not nil, with custom message
/// - Parameters:
///   - value: The optional value to check
///   - message: Custom message for the assertion
///   - file: Source file (automatically filled)
///   - line: Source line (automatically filled)
func debugAssertNotNil<T>(_ value: T?, _ message: String, file: String = #file, line: Int = #line) {
    debugAssert(value != nil, message, file: file, line: line)
}

/// Assert that a condition is true with a formatted message
/// - Parameters:
///   - condition: The condition to assert
///   - format: Format string for the message
///   - args: Arguments for the format string
///   - file: Source file (automatically filled)
///   - line: Source line (automatically filled)
func debugAssertf(_ condition: Bool, _ format: String, _ args: CVarArg..., file: String = #file, line: Int = #line) {
    let message = String(format: format, arguments: args)
    debugAssert(condition, message, file: file, line: line)
}

/// Log a debug message with formatting
/// - Parameters:
///   - format: Format string for the message
///   - args: Arguments for the format string
///   - file: Source file (automatically filled)
///   - line: Source line (automatically filled)
func debugLogf(_ format: String, _ args: CVarArg..., file: String = #file, line: Int = #line) {
    let message = String(format: format, arguments: args)
    debugLog(message, file: file, line: line)
}