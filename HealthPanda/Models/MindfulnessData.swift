//
//  MindfulnessData.swift
//  HealthPanda
//
//  Mindfulness metrics and comparison logic.
//

import Foundation

// MARK: - Mindfulness Data

/// Mindfulness metrics for a time period.
struct MindfulnessData: Sendable {
    let period: DateInterval
    let totalMinutes: Double?
    let sessionCount: Int?

    var hasAnyData: Bool {
        totalMinutes != nil || sessionCount != nil
    }

    static func empty(for period: DateInterval) -> MindfulnessData {
        MindfulnessData(period: period, totalMinutes: nil, sessionCount: nil)
    }
}

// MARK: - Mindfulness Comparison

/// Comparison of mindfulness data between two periods.
struct MindfulnessComparison: HealthComparison {
    let previous: MindfulnessData
    let current: MindfulnessData

    var hasData: Bool { current.hasAnyData }

    /// O(1) - simple nil check and arithmetic.
    private func percentChange(from prev: Double?, to curr: Double?) -> Double? {
        guard let prev, let curr, prev > 0 else { return nil }
        return ((curr - prev) / prev) * 100
    }

    var trend: TrendDirection {
        guard let prev = previous.totalMinutes,
              let curr = current.totalMinutes,
              prev > 0 else { return .stable }
        let change = ((curr - prev) / prev) * 100
        if change > 10 { return .improving }
        if change < -10 { return .declining }
        return .stable
    }

    var promptText: String {
        var lines = ["Analyze this mindfulness data. Give a brief summary."]
        if let mins = current.totalMinutes {
            lines.append("Mindful minutes: \(mins.wholeNumber)")
        }
        if let count = current.sessionCount {
            lines.append("Sessions: \(count)")
        }
        return lines.joined(separator: "\n")
    }

    var metricsDisplay: String {
        var parts: [String] = []
        if let mins = current.totalMinutes {
            parts.append("\(mins.wholeNumber) min")
        }
        if let count = current.sessionCount {
            parts.append("\(count) sessions")
        }
        return parts.joined(separator: " · ")
    }

    var fallbackSummary: String {
        switch trend {
        case .improving: return "Your mindfulness practice is growing."
        case .stable: return "Your mindfulness practice is consistent."
        case .declining: return "Your mindfulness practice has decreased."
        }
    }
}
