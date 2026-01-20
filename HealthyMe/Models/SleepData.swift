//
//  SleepData.swift
//  HealthyMe
//
//  Sleep health metrics and comparison logic.
//  Tracks sleep duration, stages (REM, Core, Deep), efficiency, and awakenings.
//

import Foundation

// MARK: - Sleep Data

/// Sleep metrics for a time period.
/// Duration values are stored in minutes; efficiency is a percentage (0-100).
struct SleepData: Sendable {
    let period: DateInterval
    let totalSleepMinutes: Double?     // Sum of all asleep stages
    let remMinutes: Double?            // REM sleep duration
    let coreMinutes: Double?           // Core (light) sleep duration
    let deepSleepMinutes: Double?      // Deep sleep duration
    let inBedMinutes: Double?          // Total time in bed
    let sleepEfficiency: Double?       // (asleep / inBed) * 100
    let awakeningsCount: Int?          // Number of awake periods during sleep

    var hasAnyData: Bool {
        totalSleepMinutes != nil || remMinutes != nil ||
        coreMinutes != nil || deepSleepMinutes != nil ||
        sleepEfficiency != nil || awakeningsCount != nil
    }

    /// Calculates sleep stage percentages if total sleep is available.
    var stagePercentages: (rem: Double, core: Double, deep: Double)? {
        guard let total = totalSleepMinutes, total > 0 else { return nil }

        let rem = (remMinutes ?? 0) / total * 100
        let core = (coreMinutes ?? 0) / total * 100
        let deep = (deepSleepMinutes ?? 0) / total * 100

        return (rem, core, deep)
    }

    static func empty(for period: DateInterval) -> SleepData {
        SleepData(
            period: period,
            totalSleepMinutes: nil,
            remMinutes: nil,
            coreMinutes: nil,
            deepSleepMinutes: nil,
            inBedMinutes: nil,
            sleepEfficiency: nil,
            awakeningsCount: nil
        )
    }
}

// MARK: - Sleep Comparison

/// Comparison of sleep data between two periods.
struct SleepComparison: HealthComparison {
    let previous: SleepData
    let current: SleepData

    var hasData: Bool { current.hasAnyData }

    // MARK: - Percentage Changes

    private func percentChange(from prev: Double?, to curr: Double?) -> Double? {
        guard let prev, let curr, prev > 0 else { return nil }
        return ((curr - prev) / prev) * 100
    }

    private func intPercentChange(from prev: Int?, to curr: Int?) -> Double? {
        guard let prev, let curr, prev > 0 else { return nil }
        return (Double(curr - prev) / Double(prev)) * 100
    }

    var sleepDurationChange: Double? {
        percentChange(from: previous.totalSleepMinutes, to: current.totalSleepMinutes)
    }

    var remChange: Double? {
        percentChange(from: previous.remMinutes, to: current.remMinutes)
    }

    var coreChange: Double? {
        percentChange(from: previous.coreMinutes, to: current.coreMinutes)
    }

    var deepChange: Double? {
        percentChange(from: previous.deepSleepMinutes, to: current.deepSleepMinutes)
    }

    var efficiencyChange: Double? {
        percentChange(from: previous.sleepEfficiency, to: current.sleepEfficiency)
    }

    var awakeningsChange: Double? {
        intPercentChange(from: previous.awakeningsCount, to: current.awakeningsCount)
    }

    // MARK: - Per-Metric Trends

    /// Individual trend indicators for each sleep metric.
    var metricTrends: [MetricTrend] {
        var trends: [MetricTrend] = []

        // Total sleep duration - more sleep (7-9 hours ideal) is generally better
        if let total = current.totalSleepMinutes {
            let direction = durationTrend()
            let hours = total / 60
            trends.append(MetricTrend(
                name: "Total Sleep",
                value: String(format: "%.1fh", hours),
                direction: direction
            ))
        }

        // REM sleep - higher is better (20-25% of sleep is ideal)
        if let rem = current.remMinutes {
            let direction = trendDirection(for: remChange, lowerIsBetter: false)
            trends.append(MetricTrend(
                name: "REM",
                value: "\(rem.wholeNumber) min",
                direction: direction
            ))
        }

        // Core (light) sleep - tracked for completeness
        if let core = current.coreMinutes {
            let direction = trendDirection(for: coreChange, lowerIsBetter: false)
            trends.append(MetricTrend(
                name: "Core",
                value: "\(core.wholeNumber) min",
                direction: direction
            ))
        }

        // Deep sleep - higher is better (13-23% of sleep is ideal)
        if let deep = current.deepSleepMinutes {
            let direction = trendDirection(for: deepChange, lowerIsBetter: false)
            trends.append(MetricTrend(
                name: "Deep",
                value: "\(deep.wholeNumber) min",
                direction: direction
            ))
        }

        // Sleep efficiency - higher is better (85%+ is good)
        if let efficiency = current.sleepEfficiency {
            let direction = efficiencyTrend()
            trends.append(MetricTrend(
                name: "Efficiency",
                value: "\(efficiency.wholeNumber)%",
                direction: direction
            ))
        }

        // Awakenings - fewer is better
        if let awakenings = current.awakeningsCount {
            let direction = awakeningsTrend()
            trends.append(MetricTrend(
                name: "Awakenings",
                value: "\(awakenings)",
                direction: direction
            ))
        }

        return trends
    }

    // MARK: - Trend Helpers

    /// Duration trend - 7-9 hours is ideal for adults.
    private func durationTrend() -> TrendDirection {
        guard let curr = current.totalSleepMinutes else { return .stable }
        let hours = curr / 60

        // Ideal range is 7-9 hours
        if hours >= 7 && hours <= 9 {
            // Within ideal range, check if we're moving toward it
            if let change = sleepDurationChange, abs(change) < 5 {
                return .stable
            }
            return sleepDurationChange ?? 0 > 0 ? .stable : .stable
        }

        // Outside ideal range - is the trend helping?
        if let change = sleepDurationChange {
            if hours < 7 && change > 5 { return .improving }
            if hours > 9 && change < -5 { return .improving }
            if hours < 7 && change < -5 { return .declining }
            if hours > 9 && change > 5 { return .declining }
        }

        return .stable
    }

    /// Efficiency trend - 85%+ is good, 90%+ is excellent.
    private func efficiencyTrend() -> TrendDirection {
        guard let efficiency = current.sleepEfficiency else { return .stable }

        if efficiency >= 85 {
            // Already good; stability is fine
            if let change = efficiencyChange, change < -5 { return .declining }
            return .stable
        }

        // Below 85%, improving is good
        if let change = efficiencyChange {
            if change > 3 { return .improving }
            if change < -3 { return .declining }
        }

        return efficiency < 75 ? .declining : .stable
    }

    /// Awakenings trend - fewer is better.
    private func awakeningsTrend() -> TrendDirection {
        guard let curr = current.awakeningsCount else { return .stable }

        // Fewer awakenings is better
        if let change = awakeningsChange {
            if change < -10 { return .improving }  // Fewer awakenings
            if change > 10 { return .declining }   // More awakenings
        }

        // Absolute judgment: >5 awakenings is concerning
        if curr > 5 { return .declining }

        return .stable
    }

    /// Generic trend direction helper.
    private func trendDirection(for change: Double?, lowerIsBetter: Bool) -> TrendDirection {
        guard let change else { return .stable }
        let threshold = 5.0

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
            Analyze this sleep data. Ideal adult sleep is 7-9 hours. REM should be 20-25%, \
            deep sleep 13-23%. Efficiency of 85%+ is good. Fewer awakenings is better. \
            Keep response under 100 characters.
            """
        ]

        if let total = current.totalSleepMinutes {
            let hours = total / 60
            let status = (hours >= 7 && hours <= 9) ? "ideal" : (hours < 7 ? "low" : "high")
            let trend = sleepDurationChange.map { $0 > 0 ? "improved" : ($0 < 0 ? "declined" : "stable") } ?? "stable"
            lines.append("Total sleep: \(String(format: "%.1f", hours))h (\(status))\(sleepDurationChange.parentheticalChange) [\(trend)]")
        }

        if let stages = current.stagePercentages {
            lines.append("Stages: REM \(String(format: "%.0f", stages.rem))%, Core \(String(format: "%.0f", stages.core))%, Deep \(String(format: "%.0f", stages.deep))%")
        } else {
            if let rem = current.remMinutes {
                lines.append("REM: \(rem.wholeNumber) min")
            }
            if let deep = current.deepSleepMinutes {
                lines.append("Deep: \(deep.wholeNumber) min")
            }
        }

        if let efficiency = current.sleepEfficiency {
            let status = efficiency >= 85 ? "good" : "needs improvement"
            lines.append("Efficiency: \(efficiency.wholeNumber)% (\(status))")
        }

        if let awakenings = current.awakeningsCount {
            lines.append("Awakenings: \(awakenings)")
        }

        return lines.joined(separator: "\n")
    }

    var metricsDisplay: String {
        var parts: [String] = []

        if let total = current.totalSleepMinutes {
            let hours = total / 60
            parts.append("\(String(format: "%.1f", hours))h avg")
        }
        if let efficiency = current.sleepEfficiency {
            parts.append("\(efficiency.wholeNumber)% eff")
        }
        if let deep = current.deepSleepMinutes {
            parts.append("\(deep.wholeNumber)m deep")
        }

        return parts.joined(separator: " · ")
    }

    var fallbackShortSummary: String {
        guard let change = sleepDurationChange else {
            return "Sleep data available"
        }
        let absChange = abs(change)
        switch trend {
        case .improving:
            return "Sleep up \(absChange.wholeNumber)%"
        case .declining:
            return "Sleep down \(absChange.wholeNumber)%"
        case .stable:
            return "Sleep stable"
        }
    }

    var fallbackSummary: String {
        switch trend {
        case .improving:
            return "Your sleep quality is improving."
        case .stable:
            return "Your sleep patterns remain consistent."
        case .declining:
            return "Your sleep quality has decreased."
        }
    }
}
