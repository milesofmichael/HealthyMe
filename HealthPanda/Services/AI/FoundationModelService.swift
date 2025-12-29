//
//  FoundationModelService.swift
//  HealthPanda
//
//  Apple Foundation Models implementation. Requires iOS 26+ with Apple Intelligence enabled.
//

import Foundation
import OSLog

#if canImport(FoundationModels)
import FoundationModels
#endif

final class FoundationModelService: AiServiceProtocol, SummaryServiceProtocol, @unchecked Sendable {

    static let shared = FoundationModelService()

    private let logger = Logger(subsystem: "com.healthpanda", category: "FoundationModelService")

    // MARK: - AiServiceProtocol

    func checkAvailability() async -> AiAvailabilityStatus {
        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default

        switch model.availability {
        case .available:
            logger.info("Foundation Models available")
            return .available

        case .unavailable(let reason):
            let reasonString = String(describing: reason)
            logger.warning("Foundation Models unavailable: \(reasonString)")

            if reasonString.lowercased().contains("disabled") ||
               reasonString.lowercased().contains("not enabled") {
                return .disabledByUser
            }
            return .unavailableDevice(reason: reasonString)

        @unknown default:
            logger.error("Unknown availability state")
            return .unavailableDevice(reason: "Unknown availability state")
        }
        #else
        logger.warning("FoundationModels not available")
        return .unavailableDevice(reason: "This device does not support Apple Intelligence")
        #endif
    }

    // MARK: - SummaryServiceProtocol

    func generateHeartSummary(comparison: HeartComparison) async throws -> HealthSummary {
        let prompt = buildHeartPrompt(comparison: comparison)

        #if canImport(FoundationModels)
        let session = LanguageModelSession()
        let response = try await session.respond(to: prompt)
        return parseResponse(response.content)
        #else
        // Fallback for devices without Foundation Models
        return generateFallbackSummary(comparison: comparison)
        #endif
    }

    // MARK: - Private

    private func buildHeartPrompt(comparison: HeartComparison) -> String {
        var lines: [String] = []
        lines.append("Analyze this heart health data comparing last month to this month.")
        lines.append("")

        // Current values
        lines.append("This month's averages:")
        if let hr = comparison.current.heartRate {
            lines.append("- Heart rate: \(String(format: "%.0f", hr)) BPM")
        }
        if let rhr = comparison.current.restingHeartRate {
            lines.append("- Resting heart rate: \(String(format: "%.0f", rhr)) BPM")
        }
        if let o2 = comparison.current.bloodOxygen {
            lines.append("- Blood oxygen: \(String(format: "%.1f", o2))%")
        }
        if let whr = comparison.current.walkingHeartRate {
            lines.append("- Walking heart rate: \(String(format: "%.0f", whr)) BPM")
        }
        if let hrv = comparison.current.hrv {
            lines.append("- HRV: \(String(format: "%.0f", hrv)) ms")
        }

        lines.append("")
        lines.append("Changes from last month:")
        if let change = comparison.heartRateChange {
            lines.append("- Heart rate: \(change >= 0 ? "+" : "")\(String(format: "%.1f", change))%")
        }
        if let change = comparison.restingHeartRateChange {
            lines.append("- Resting heart rate: \(change >= 0 ? "+" : "")\(String(format: "%.1f", change))%")
        }
        if let change = comparison.bloodOxygenChange {
            lines.append("- Blood oxygen: \(change >= 0 ? "+" : "")\(String(format: "%.1f", change))%")
        }
        if let change = comparison.hrvChange {
            lines.append("- HRV: \(change >= 0 ? "+" : "")\(String(format: "%.1f", change))%")
        }

        lines.append("")
        lines.append("Respond in exactly this format:")
        lines.append("SMALL: [One sentence, max 50 chars, about the overall trend]")
        lines.append("LARGE: [2-3 sentences explaining the trends and what they mean for health]")

        return lines.joined(separator: "\n")
    }

    private func parseResponse(_ content: String) -> HealthSummary {
        var small = "Your heart health looks stable"
        var large = "Your heart metrics are within normal ranges."

        let lines = content.components(separatedBy: "\n")
        for line in lines {
            if line.uppercased().hasPrefix("SMALL:") {
                small = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if line.uppercased().hasPrefix("LARGE:") {
                large = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            }
        }

        return HealthSummary(small: small, large: large)
    }

    private func generateFallbackSummary(comparison: HeartComparison) -> HealthSummary {
        // Simple fallback when LLM isn't available
        var trend = "stable"
        if let change = comparison.heartRateChange {
            if change > 5 { trend = "slightly elevated" }
            else if change < -5 { trend = "improving" }
        }

        let small = "Heart rate is \(trend)"
        var large = "Your heart metrics from this month compared to last month show \(trend) patterns. "

        if let hr = comparison.current.heartRate {
            large += "Average heart rate: \(String(format: "%.0f", hr)) BPM. "
        }
        if let rhr = comparison.current.restingHeartRate {
            large += "Resting heart rate: \(String(format: "%.0f", rhr)) BPM. "
        }

        return HealthSummary(small: small, large: large)
    }
}
