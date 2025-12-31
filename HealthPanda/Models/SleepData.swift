//
//  SleepData.swift
//  HealthPanda
//
//  Sleep health metrics and comparison logic.
//

import Foundation

// MARK: - Sleep Data

/// Sleep metrics for a time period.
struct SleepData: Sendable {
    let period: DateInterval
    let totalSleepMinutes: Double?
    let remMinutes: Double?
    let deepSleepMinutes: Double?
    let awakeMinutes: Double?

    var hasAnyData: Bool {
        totalSleepMinutes != nil || remMinutes != nil ||
        deepSleepMinutes != nil || awakeMinutes != nil
    }

    static func empty(for period: DateInterval) -> SleepData {
        SleepData(period: period, totalSleepMinutes: nil,
                  remMinutes: nil, deepSleepMinutes: nil, awakeMinutes: nil)
    }
}

// MARK: - Sleep Comparison

/// Comparison of sleep data between two periods.
struct SleepComparison: HealthComparison {
    let previous: SleepData
    let current: SleepData

    var hasData: Bool { current.hasAnyData }

    var sleepDurationChange: Double? {
        percentChange(from: previous.totalSleepMinutes, to: current.totalSleepMinutes)
    }

    private func percentChange(from prev: Double?, to curr: Double?) -> Double? {
        guard let prev, let curr, prev > 0 else { return nil }
        return ((curr - prev) / prev) * 100
    }

    // MARK: - HealthComparison Protocol

    var trend: TrendDirection {
        guard let change = sleepDurationChange else { return .stable }
        if change > 5 { return .improving }
        if change < -5 { return .declining }
        return .stable
    }

    var promptText: String {
        var lines = ["Analyze this sleep data. Give a brief summary."]

        if let total = current.totalSleepMinutes {
            let hours = total / 60
            lines.append("Total sleep: \(hours.wholeNumber) hours\(sleepDurationChange.parentheticalChange)")
        }
        if let rem = current.remMinutes {
            lines.append("REM sleep: \(rem.wholeNumber) min")
        }
        if let deep = current.deepSleepMinutes {
            lines.append("Deep sleep: \(deep.wholeNumber) min")
        }

        return lines.joined(separator: "\n")
    }

    var metricsDisplay: String {
        var parts: [String] = []

        if let total = current.totalSleepMinutes {
            let hours = total / 60
            parts.append("\(hours.wholeNumber)h avg")
        }
        if let rem = current.remMinutes {
            parts.append("\(rem.wholeNumber)m REM")
        }

        return parts.joined(separator: " · ")
    }

    var fallbackSummary: String {
        switch trend {
        case .improving:
            return "Your sleep duration is improving."
        case .stable:
            return "Your sleep patterns remain consistent."
        case .declining:
            return "Your sleep duration has decreased."
        }
    }
}
