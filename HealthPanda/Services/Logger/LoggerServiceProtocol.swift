//
//  LoggerServiceProtocol.swift
//  HealthPanda
//
//  Protocol for centralized logging with file/line context.
//

import Foundation

/// Log levels matching OSLog levels.
enum LogLevel {
    case debug
    case info
    case warning
    case error
}

/// Protocol for logging services.
/// Uses default parameter values to capture call site info automatically.
protocol LoggerServiceProtocol {
    func log(
        _ message: String,
        level: LogLevel,
        file: String,
        line: Int
    )
}

// Convenience methods with default parameters for call site capture
extension LoggerServiceProtocol {
    func debug(_ message: String, file: String = #fileID, line: Int = #line) {
        log(message, level: .debug, file: file, line: line)
    }

    func info(_ message: String, file: String = #fileID, line: Int = #line) {
        log(message, level: .info, file: file, line: line)
    }

    func warning(_ message: String, file: String = #fileID, line: Int = #line) {
        log(message, level: .warning, file: file, line: line)
    }

    func error(_ message: String, file: String = #fileID, line: Int = #line) {
        log(message, level: .error, file: file, line: line)
    }
}
