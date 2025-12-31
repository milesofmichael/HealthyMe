//
//  PerformanceData.swift
//  HealthPanda
//
//  Performance/activity metrics and comparison logic.
//

import Foundation

// MARK: - Performance Data

/// Activity and performance metrics for a time period.
struct PerformanceData: Sendable {
    let period: DateInterval
    let stepCount: Double?
    let activeCalories: Double?
    let exerciseMinutes: Double?
    let distanceMeters: Double?

    var hasAnyData: Bool {
        stepCount != nil || activeCalories != nil ||
        exerciseMinutes != nil || distanceMeters != nil
    }

    static func empty(for period: DateInterval) -> PerformanceData {
        PerformanceData(period: period, stepCount: nil,
                        activeCalories: nil, exerciseMinutes: nil, distanceMeters: nil)
    }
}

// MARK: - Performance Comparison

/// Comparison of performance data between two periods.
struct PerformanceComparison: HealthComparison {
    let previous: PerformanceData
    let current: PerformanceData

    var hasData: Bool { current.hasAnyData }

    /// O(1) - simple nil check and arithmetic.
    private func percentChange(from prev: Double?, to curr: Double?) -> Double? {
        guard let prev, let curr, prev > 0 else { return nil }
        return ((curr - prev) / prev) * 100
    }

    var stepCountChange: Double? {
        percentChange(from: previous.stepCount, to: current.stepCount)
    }

    var trend: TrendDirection {
        guard let change = stepCountChange else { return .stable }
        if change > 10 { return .improving }
        if change < -10 { return .declining }
        return .stable
    }

    var promptText: String {
        var lines = ["Analyze this activity data. Give a brief summary."]
        if let steps = current.stepCount {
            lines.append("Steps: \(steps.wholeNumber)\(stepCountChange.parentheticalChange)")
        }
        if let cals = current.activeCalories {
            lines.append("Active calories: \(cals.wholeNumber)")
        }
        if let mins = current.exerciseMinutes {
            lines.append("Exercise: \(mins.wholeNumber) min")
        }
        return lines.joined(separator: "\n")
    }

    var metricsDisplay: String {
        var parts: [String] = []
        if let steps = current.stepCount {
            parts.append("\(steps.wholeNumber) steps")
        }
        if let cals = current.activeCalories {
            parts.append("\(cals.wholeNumber) cal")
        }
        return parts.joined(separator: " · ")
    }

    var fallbackSummary: String {
        switch trend {
        case .improving: return "Your activity levels are increasing."
        case .stable: return "Your activity levels are consistent."
        case .declining: return "Your activity levels have decreased."
        }
    }
}
