//
//  VitalityData.swift
//  HealthPanda
//
//  Vitality metrics and comparison logic.
//

import Foundation

// MARK: - Vitality Data

/// Vital signs for a time period.
struct VitalityData: Sendable {
    let period: DateInterval
    let bodyTemperature: Double?
    let respiratoryRate: Double?
    let systolicBP: Double?
    let diastolicBP: Double?

    var hasAnyData: Bool {
        bodyTemperature != nil || respiratoryRate != nil ||
        systolicBP != nil || diastolicBP != nil
    }

    static func empty(for period: DateInterval) -> VitalityData {
        VitalityData(period: period, bodyTemperature: nil,
                     respiratoryRate: nil, systolicBP: nil, diastolicBP: nil)
    }
}

// MARK: - Vitality Comparison

/// Comparison of vitality data between two periods.
struct VitalityComparison: HealthComparison {
    let previous: VitalityData
    let current: VitalityData

    var hasData: Bool { current.hasAnyData }

    /// O(1) - simple nil check and arithmetic.
    private func percentChange(from prev: Double?, to curr: Double?) -> Double? {
        guard let prev, let curr, prev > 0 else { return nil }
        return ((curr - prev) / prev) * 100
    }

    var trend: TrendDirection {
        // Vitals are best when stable
        .stable
    }

    var promptText: String {
        var lines = ["Analyze this vitals data. Give a brief summary."]
        if let temp = current.bodyTemperature {
            lines.append("Body temp: \(String(format: "%.1f", temp))°F")
        }
        if let rr = current.respiratoryRate {
            lines.append("Respiratory rate: \(rr.wholeNumber)/min")
        }
        if let sys = current.systolicBP, let dia = current.diastolicBP {
            lines.append("Blood pressure: \(sys.wholeNumber)/\(dia.wholeNumber)")
        }
        return lines.joined(separator: "\n")
    }

    var metricsDisplay: String {
        var parts: [String] = []
        if let temp = current.bodyTemperature {
            parts.append("\(String(format: "%.1f", temp))°F")
        }
        if let sys = current.systolicBP, let dia = current.diastolicBP {
            parts.append("\(sys.wholeNumber)/\(dia.wholeNumber)")
        }
        return parts.joined(separator: " · ")
    }

    var fallbackShortSummary: String {
        "Vitals normal"
    }

    var fallbackSummary: String {
        "Your vitals are within normal range."
    }
}
