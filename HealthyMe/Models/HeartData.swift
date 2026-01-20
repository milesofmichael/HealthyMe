//
//  HeartData.swift
//  HealthyMe
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
    let walkingHeartRate: Double?
    let hrv: Double?

    var hasCriticalData: Bool { heartRate != nil }

    var hasAnyData: Bool {
        heartRate != nil || restingHeartRate != nil ||
        walkingHeartRate != nil || hrv != nil
    }

    static func empty(for period: DateInterval) -> HeartData {
        HeartData(period: period, heartRate: nil, restingHeartRate: nil,
                  walkingHeartRate: nil, hrv: nil)
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

    var walkingHeartRateChange: Double? {
        percentChange(from: previous.walkingHeartRate, to: current.walkingHeartRate)
    }

    var hrvChange: Double? {
        percentChange(from: previous.hrv, to: current.hrv)
    }

    private func percentChange(from prev: Double?, to curr: Double?) -> Double? {
        guard let prev, let curr, prev > 0 else { return nil }
        return ((curr - prev) / prev) * 100
    }

    // MARK: - Per-Metric Trends

    /// Individual trend indicators for each heart metric.
    /// For heart rate metrics, LOWER is better. For HRV, HIGHER is better.
    var metricTrends: [MetricTrend] {
        var trends: [MetricTrend] = []

        // Average heart rate - lower is generally better (indicates efficiency)
        if let hr = current.heartRate {
            let direction = trendDirection(for: heartRateChange, lowerIsBetter: true)
            trends.append(MetricTrend(
                name: "Avg HR",
                value: "\(hr.wholeNumber) BPM",
                direction: direction
            ))
        }

        // Resting heart rate - lower is better (indicates cardiovascular fitness)
        if let rhr = current.restingHeartRate {
            let direction = trendDirection(for: restingHeartRateChange, lowerIsBetter: true)
            trends.append(MetricTrend(
                name: "Resting",
                value: "\(rhr.wholeNumber) BPM",
                direction: direction
            ))
        }

        // Walking heart rate - lower is better (indicates fitness)
        if let whr = current.walkingHeartRate {
            let direction = trendDirection(for: walkingHeartRateChange, lowerIsBetter: true)
            trends.append(MetricTrend(
                name: "Walking",
                value: "\(whr.wholeNumber) BPM",
                direction: direction
            ))
        }

        // HRV - HIGHER is better (indicates recovery and adaptability)
        if let hrv = current.hrv {
            let direction = trendDirection(for: hrvChange, lowerIsBetter: false)
            trends.append(MetricTrend(
                name: "HRV",
                value: "\(hrv.wholeNumber) ms",
                direction: direction
            ))
        }

        return trends
    }

    /// Determines trend direction for a metric given its change percentage.
    /// - Parameters:
    ///   - change: Percentage change (positive = increased, negative = decreased)
    ///   - lowerIsBetter: If true, a decrease is "improving"; if false, an increase is "improving"
    private func trendDirection(for change: Double?, lowerIsBetter: Bool) -> TrendDirection {
        guard let change else { return .stable }
        let threshold = 3.0 // 3% change threshold for significance

        if abs(change) < threshold { return .stable }

        // If value went down (negative change)
        if change < 0 {
            return lowerIsBetter ? .improving : .declining
        }
        // If value went up (positive change)
        return lowerIsBetter ? .declining : .improving
    }

    // MARK: - HealthComparison Protocol

    /// Aggregate trend based on majority of metrics.
    /// Counts improving vs declining metrics to determine overall direction.
    var trend: TrendDirection {
        let trends = metricTrends
        guard !trends.isEmpty else { return .stable }

        let improving = trends.filter { $0.direction == .improving }.count
        let declining = trends.filter { $0.direction == .declining }.count

        if improving > declining { return .improving }
        if declining > improving { return .declining }
        return .stable
    }

    /// Prompt for LLM to analyze this comparison.
    /// Provides clear instructions for analyzing each metric individually.
    var promptText: String {
        var lines = [
            """
            Analyze each heart metric individually. For heart rate metrics, LOWER values indicate \
            better cardiovascular fitness. For HRV, HIGHER values indicate better recovery. \
            Be specific about which metrics improved and which declined - do not say "overall \
            improvement" unless ALL metrics improved. Keep response under 100 characters.
            """
        ]

        if let hr = current.heartRate {
            let trend = heartRateChange.map { $0 < 0 ? "improved" : ($0 > 0 ? "worsened" : "stable") } ?? "stable"
            lines.append("Avg heart rate: \(hr.wholeNumber) BPM\(heartRateChange.parentheticalChange) [\(trend)]")
        }
        if let rhr = current.restingHeartRate {
            let trend = restingHeartRateChange.map { $0 < 0 ? "improved" : ($0 > 0 ? "worsened" : "stable") } ?? "stable"
            lines.append("Resting HR: \(rhr.wholeNumber) BPM\(restingHeartRateChange.parentheticalChange) [\(trend)]")
        }
        if let whr = current.walkingHeartRate {
            let trend = walkingHeartRateChange.map { $0 < 0 ? "improved" : ($0 > 0 ? "worsened" : "stable") } ?? "stable"
            lines.append("Walking HR: \(whr.wholeNumber) BPM\(walkingHeartRateChange.parentheticalChange) [\(trend)]")
        }
        if let hrv = current.hrv {
            // HRV is inverse - higher is better
            let trend = hrvChange.map { $0 > 0 ? "improved" : ($0 < 0 ? "worsened" : "stable") } ?? "stable"
            lines.append("HRV: \(hrv.wholeNumber) ms\(hrvChange.parentheticalChange) [\(trend)]")
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
