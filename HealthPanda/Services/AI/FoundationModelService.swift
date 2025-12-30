//
//  FoundationModelService.swift
//  HealthPanda
//
//  Apple Foundation Models implementation. Requires iOS 26+ with Apple Intelligence enabled.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

final class FoundationModelService: AiServiceProtocol, SummaryServiceProtocol {

    static let shared = FoundationModelService()

    private let logger: LoggerServiceProtocol = LoggerService.shared

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
        #if canImport(FoundationModels)
        let prompt = buildHeartPrompt(comparison: comparison)

        let session = LanguageModelSession()
        let response = try await session.respond(
            to: prompt,
            generating: HeartSummaryResponse.self
        )

        logger.info("Generated heart summary with trend: \(response.content.trend)")
        return HealthSummary(
            small: response.content.smallSummary,
            large: response.content.largeSummary
        )
        #else
        return generateFallbackSummary(comparison: comparison)
        #endif
    }

    // MARK: - Private

    private func buildHeartPrompt(comparison: HeartComparison) -> String {
        var lines: [String] = []
        lines.append("Analyze this heart health data comparing last month to this month.")
        lines.append("")

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

        return lines.joined(separator: "\n")
    }

    private func generateFallbackSummary(comparison: HeartComparison) -> HealthSummary {
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
