//
//  LoggerService.swift
//  HealthPanda
//
//  Centralized logging service using OSLog.
//  Formats: "FileName, line N: message"
//

import OSLog

final class LoggerService: LoggerServiceProtocol {

    static let shared = LoggerService()

    private let logger = Logger(subsystem: "com.healthpanda", category: "app")

    func log(_ message: String, level: LogLevel, file: String, line: Int) {
        // Extract just the file name from the fileID (e.g., "HealthPanda/HealthCache.swift" -> "HealthCache")
        let fileName = extractFileName(from: file)
        let formatted = "\(fileName), line \(line): \(message)"

        switch level {
        case .debug:
            logger.debug("\(formatted)")
        case .info:
            logger.info("\(formatted)")
        case .warning:
            logger.warning("\(formatted)")
        case .error:
            logger.error("\(formatted)")
        }
    }

    /// Extracts file name without extension from #fileID.
    /// Example: "HealthPanda/Services/Cache/HealthCache.swift" -> "HealthCache"
    private func extractFileName(from fileID: String) -> String {
        // #fileID format: "ModuleName/Path/FileName.swift"
        let lastComponent = fileID.split(separator: "/").last ?? Substring(fileID)
        let withoutExtension = lastComponent.split(separator: ".").first ?? lastComponent
        return String(withoutExtension)
    }
}
