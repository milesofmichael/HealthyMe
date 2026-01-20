//
//  MindfulnessData.swift
//  HealthyMe
//
//  Mindfulness metrics and comparison logic.
//  Tracks total mindful minutes, session count, and average session duration.
//

import Foundation

// MARK: - Mindfulness Data

/// Mindfulness metrics for a time period.
struct MindfulnessData: Sendable {
    let period: DateInterval
    let totalMinutes: Double?          // Sum of all mindful session durations
    let sessionCount: Int?             // Number of mindfulness sessions logged
    let averageSessionDuration: Double?  // Average duration per session (minutes)

    var hasAnyData: Bool {
        totalMinutes != nil || sessionCount != nil || averageSessionDuration != nil
    }

    /// Computed average if not provided but total and count are available.
    var effectiveAverageDuration: Double? {
        if let avg = averageSessionDuration { return avg }
        guard let total = totalMinutes, let count = sessionCount, count > 0 else { return nil }
        return total / Double(count)
    }

    static func empty(for period: DateInterval) -> MindfulnessData {
        MindfulnessData(
            period: period,
            totalMinutes: nil,
            sessionCount: nil,
            averageSessionDuration: nil
        )
    }
}

// MARK: - Mindfulness Comparison

/// Comparison of mindfulness data between two periods.
struct MindfulnessComparison: HealthComparison {
    let previous: MindfulnessData
    let current: MindfulnessData

    var hasData: Bool { current.hasAnyData }

    // MARK: - Percentage Changes

    /// O(1) - simple nil check and arithmetic.
    private func percentChange(from prev: Double?, to curr: Double?) -> Double? {
        guard let prev, let curr, prev > 0 else { return nil }
        return ((curr - prev) / prev) * 100
    }

    private func intPercentChange(from prev: Int?, to curr: Int?) -> Double? {
        guard let prev, let curr, prev > 0 else { return nil }
        return (Double(curr - prev) / Double(prev)) * 100
    }

    var totalMinutesChange: Double? {
        percentChange(from: previous.totalMinutes, to: current.totalMinutes)
    }

    var sessionCountChange: Double? {
        intPercentChange(from: previous.sessionCount, to: current.sessionCount)
    }

    var avgDurationChange: Double? {
        percentChange(from: previous.effectiveAverageDuration, to: current.effectiveAverageDuration)
    }

    // MARK: - Per-Metric Trends

    /// Individual trend indicators for each mindfulness metric.
    /// For mindfulness, more is generally better (higher engagement with practice).
    var metricTrends: [MetricTrend] {
        var trends: [MetricTrend] = []

        // Total mindful minutes - more is better
        if let total = current.totalMinutes {
            let direction = trendDirection(for: totalMinutesChange, lowerIsBetter: false)
            trends.append(MetricTrend(
                name: "Total Time",
                value: "\(total.wholeNumber) min",
                direction: direction
            ))
        }

        // Session count - more sessions indicates consistency
        if let count = current.sessionCount {
            let direction = sessionCountTrend()
            trends.append(MetricTrend(
                name: "Sessions",
                value: "\(count)",
                direction: direction
            ))
        }

        // Average session duration - consistency is good; too short may mean incomplete sessions
        if let avg = current.effectiveAverageDuration {
            let direction = avgDurationTrend()
            trends.append(MetricTrend(
                name: "Avg Duration",
                value: "\(avg.wholeNumber) min",
                direction: direction
            ))
        }

        return trends
    }

    // MARK: - Trend Helpers

    /// Session count trend - more sessions is better for habit building.
    private func sessionCountTrend() -> TrendDirection {
        guard let change = sessionCountChange else { return .stable }

        if change > 10 { return .improving }  // More sessions
        if change < -10 { return .declining } // Fewer sessions

        return .stable
    }

    /// Average duration trend - longer sessions indicate deeper practice.
    /// Very short sessions (<5 min) may indicate incomplete practice.
    private func avgDurationTrend() -> TrendDirection {
        guard let avg = current.effectiveAverageDuration else { return .stable }

        // Very short sessions are concerning
        if avg < 5 { return .declining }

        // If already at good duration (10+ min), stability is fine
        if avg >= 10 {
            if let change = avgDurationChange, change < -20 { return .declining }
            return .stable
        }

        // Growing toward longer sessions is good
        if let change = avgDurationChange {
            if change > 10 { return .improving }
            if change < -10 { return .declining }
        }

        return .stable
    }

    /// Generic trend direction helper.
    private func trendDirection(for change: Double?, lowerIsBetter: Bool) -> TrendDirection {
        guard let change else { return .stable }
        let threshold = 10.0  // 10% threshold for mindfulness (more variable)

        if abs(change) < threshold { return .stable }

        if change < 0 {
            return lowerIsBetter ? .improving : .declining
        }
        return lowerIsBetter ? .declining : .improving
    }

    // MARK: - HealthComparison Protocol

    /// Aggregate trend based on majority of metrics.
    var trend: TrendDirection {
        let trends = metricTrends
        guard !trends.isEmpty else { return .stable }

        let improving = trends.filter { $0.direction == .improving }.count
        let declining = trends.filter { $0.direction == .declining }.count

        if improving > declining { return .improving }
        if declining > improving { return .declining }
        return .stable
    }

    var promptText: String {
        var lines = [
            """
            Analyze this mindfulness practice data. More total minutes and sessions indicate \
            consistent practice. Longer average sessions (10+ min) show deeper engagement. \
            Keep response under 100 characters.
            """
        ]

        if let total = current.totalMinutes {
            let trend = totalMinutesChange.map { $0 > 0 ? "improved" : ($0 < 0 ? "declined" : "stable") } ?? "stable"
            lines.append("Total mindful time: \(total.wholeNumber) min\(totalMinutesChange.parentheticalChange) [\(trend)]")
        }
        if let count = current.sessionCount {
            let trend = sessionCountChange.map { $0 > 0 ? "improved" : ($0 < 0 ? "declined" : "stable") } ?? "stable"
            lines.append("Sessions: \(count)\(sessionCountChange.parentheticalChange) [\(trend)]")
        }
        if let avg = current.effectiveAverageDuration {
            let quality = avg >= 10 ? "good" : (avg >= 5 ? "moderate" : "short")
            lines.append("Avg session: \(avg.wholeNumber) min (\(quality))")
        }

        return lines.joined(separator: "\n")
    }

    var metricsDisplay: String {
        var parts: [String] = []

        if let total = current.totalMinutes {
            parts.append("\(total.wholeNumber) min")
        }
        if let count = current.sessionCount {
            parts.append("\(count) sessions")
        }
        if parts.isEmpty, let avg = current.effectiveAverageDuration {
            parts.append("\(avg.wholeNumber) min avg")
        }

        return parts.joined(separator: " · ")
    }

    var fallbackShortSummary: String {
        guard let change = totalMinutesChange else {
            if current.sessionCount != nil || current.totalMinutes != nil {
                return "Mindfulness data available"
            }
            return "No mindfulness data"
        }
        let absChange = abs(change)
        switch trend {
        case .improving:
            return "Mindfulness up \(absChange.wholeNumber)%"
        case .declining:
            return "Mindfulness down \(absChange.wholeNumber)%"
        case .stable:
            return "Mindfulness stable"
        }
    }

    var fallbackSummary: String {
        switch trend {
        case .improving:
            return "Your mindfulness practice is growing."
        case .stable:
            return "Your mindfulness practice is consistent."
        case .declining:
            return "Your mindfulness practice has decreased."
        }
    }
}
