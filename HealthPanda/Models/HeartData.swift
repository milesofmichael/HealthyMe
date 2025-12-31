//
//  HeartData.swift
//  HealthPanda
//
//  Heart health metrics and comparison logic.
//

import Foundation

// MARK: - Heart Data

/// Heart health metrics averaged over a time period.
struct HeartData: Sendable {
    let period: DateInterval
    let heartRate: Double?
    let restingHeartRate: Double?
    let bloodOxygen: Double?
    let walkingHeartRate: Double?
    let hrv: Double?

    var hasCriticalData: Bool { heartRate != nil }

    var hasAnyData: Bool {
        heartRate != nil || restingHeartRate != nil || bloodOxygen != nil ||
        walkingHeartRate != nil || hrv != nil
    }

    static func empty(for period: DateInterval) -> HeartData {
        HeartData(period: period, heartRate: nil, restingHeartRate: nil,
                  bloodOxygen: nil, walkingHeartRate: nil, hrv: nil)
    }
}

// MARK: - Heart Comparison

/// Comparison of heart data between two periods.
struct HeartComparison: HealthComparison {
    let previous: HeartData
    let current: HeartData

    var hasData: Bool { current.hasAnyData }

    // MARK: - Percentage Changes

    var heartRateChange: Double? {
        percentChange(from: previous.heartRate, to: current.heartRate)
    }

    var restingHeartRateChange: Double? {
        percentChange(from: previous.restingHeartRate, to: current.restingHeartRate)
    }

    var bloodOxygenChange: Double? {
        percentChange(from: previous.bloodOxygen, to: current.bloodOxygen)
    }

    var hrvChange: Double? {
        percentChange(from: previous.hrv, to: current.hrv)
    }

    private func percentChange(from prev: Double?, to curr: Double?) -> Double? {
        guard let prev, let curr, prev > 0 else { return nil }
        return ((curr - prev) / prev) * 100
    }

    // MARK: - HealthComparison Protocol

    /// Determines trend based on heart rate (lower is better for resting metrics).
    var trend: TrendDirection {
        guard let change = heartRateChange else { return .stable }
        if change < -3 { return .improving }
        if change > 3 { return .declining }
        return .stable
    }

    /// Prompt for LLM to analyze this comparison.
    var promptText: String {
        var lines = ["Analyze this heart health data. Give a brief summary."]

        if let hr = current.heartRate {
            lines.append("Heart rate: \(hr.wholeNumber) BPM\(heartRateChange.parentheticalChange)")
        }
        if let rhr = current.restingHeartRate {
            lines.append("Resting HR: \(rhr.wholeNumber) BPM\(restingHeartRateChange.parentheticalChange)")
        }
        if let o2 = current.bloodOxygen {
            lines.append("Blood oxygen: \(o2.wholeNumber)%\(bloodOxygenChange.parentheticalChange)")
        }
        if let hrv = current.hrv {
            lines.append("HRV: \(hrv.wholeNumber) ms\(hrvChange.parentheticalChange)")
        }

        return lines.joined(separator: "\n")
    }

    /// Formatted metrics for display in the UI.
    var metricsDisplay: String {
        var parts: [String] = []

        if let hr = current.heartRate {
            parts.append("\(hr.wholeNumber) BPM avg")
        }
        if let rhr = current.restingHeartRate {
            parts.append("\(rhr.wholeNumber) resting")
        }
        if let o2 = current.bloodOxygen {
            parts.append("\(o2.wholeNumber)% O₂")
        }

        return parts.joined(separator: " · ")
    }

    /// Brief fallback summary (~50 chars) when LLM is unavailable.
    var fallbackShortSummary: String {
        guard let change = heartRateChange else {
            return "Heart data available"
        }
        let direction = change < 0 ? "down" : "up"
        let absChange = abs(change)
        switch trend {
        case .improving:
            return "Heart rate \(direction) \(absChange.wholeNumber)%"
        case .declining:
            return "Heart rate \(direction) \(absChange.wholeNumber)%"
        case .stable:
            return "Heart rate stable"
        }
    }

    /// Detailed fallback summary when LLM is unavailable.
    var fallbackSummary: String {
        switch trend {
        case .improving:
            return "Your heart metrics are showing improvement."
        case .stable:
            return "Your heart metrics remain stable."
        case .declining:
            return "Your heart metrics are slightly elevated."
        }
    }
}
