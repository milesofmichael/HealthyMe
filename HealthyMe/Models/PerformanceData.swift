//
//  PerformanceData.swift
//  HealthyMe
//
//  Performance/activity metrics and comparison logic.
//  Includes step count, distance, calories, exercise time, VO2 max, walking speed,
//  and six-minute walk test distance for comprehensive fitness tracking.
//

import Foundation

// MARK: - Performance Data

/// Activity and performance metrics for a time period.
/// All distance values stored in meters, speed in m/s.
struct PerformanceData: Sendable {
    let period: DateInterval
    let stepCount: Double?
    let distanceMeters: Double?
    let activeCalories: Double?
    let exerciseMinutes: Double?
    let vo2Max: Double?                    // ml/kg/min - maximal oxygen consumption
    let walkingSpeed: Double?              // m/s - average walking pace
    let sixMinuteWalkDistance: Double?     // meters - standardized fitness test

    var hasAnyData: Bool {
        stepCount != nil || distanceMeters != nil ||
        activeCalories != nil || exerciseMinutes != nil ||
        vo2Max != nil || walkingSpeed != nil || sixMinuteWalkDistance != nil
    }

    static func empty(for period: DateInterval) -> PerformanceData {
        PerformanceData(
            period: period,
            stepCount: nil,
            distanceMeters: nil,
            activeCalories: nil,
            exerciseMinutes: nil,
            vo2Max: nil,
            walkingSpeed: nil,
            sixMinuteWalkDistance: nil
        )
    }
}

// MARK: - Performance Comparison

/// Comparison of performance data between two periods.
struct PerformanceComparison: HealthComparison {
    let previous: PerformanceData
    let current: PerformanceData

    var hasData: Bool { current.hasAnyData }

    // MARK: - Percentage Changes

    /// O(1) - simple nil check and arithmetic.
    private func percentChange(from prev: Double?, to curr: Double?) -> Double? {
        guard let prev, let curr, prev > 0 else { return nil }
        return ((curr - prev) / prev) * 100
    }

    var stepCountChange: Double? {
        percentChange(from: previous.stepCount, to: current.stepCount)
    }

    var distanceChange: Double? {
        percentChange(from: previous.distanceMeters, to: current.distanceMeters)
    }

    var caloriesChange: Double? {
        percentChange(from: previous.activeCalories, to: current.activeCalories)
    }

    var exerciseChange: Double? {
        percentChange(from: previous.exerciseMinutes, to: current.exerciseMinutes)
    }

    var vo2MaxChange: Double? {
        percentChange(from: previous.vo2Max, to: current.vo2Max)
    }

    var walkingSpeedChange: Double? {
        percentChange(from: previous.walkingSpeed, to: current.walkingSpeed)
    }

    var sixMinWalkChange: Double? {
        percentChange(from: previous.sixMinuteWalkDistance, to: current.sixMinuteWalkDistance)
    }

    // MARK: - Per-Metric Trends

    /// Individual trend indicators for each performance metric.
    /// For all performance metrics, HIGHER is better (more activity = better fitness).
    var metricTrends: [MetricTrend] {
        var trends: [MetricTrend] = []

        // Step count - higher is better
        if let steps = current.stepCount {
            let direction = trendDirection(for: stepCountChange, lowerIsBetter: false)
            trends.append(MetricTrend(
                name: "Steps",
                value: steps.formattedWithCommas,
                direction: direction
            ))
        }

        // Distance - higher is better
        if let dist = current.distanceMeters {
            let direction = trendDirection(for: distanceChange, lowerIsBetter: false)
            let km = dist / 1000
            trends.append(MetricTrend(
                name: "Distance",
                value: String(format: "%.1f km", km),
                direction: direction
            ))
        }

        // Active calories - higher is better
        if let cals = current.activeCalories {
            let direction = trendDirection(for: caloriesChange, lowerIsBetter: false)
            trends.append(MetricTrend(
                name: "Calories",
                value: "\(cals.wholeNumber) kcal",
                direction: direction
            ))
        }

        // Exercise minutes - higher is better
        if let mins = current.exerciseMinutes {
            let direction = trendDirection(for: exerciseChange, lowerIsBetter: false)
            trends.append(MetricTrend(
                name: "Exercise",
                value: "\(mins.wholeNumber) min",
                direction: direction
            ))
        }

        // VO2 Max - higher is better (indicates cardiovascular fitness)
        if let vo2 = current.vo2Max {
            let direction = trendDirection(for: vo2MaxChange, lowerIsBetter: false)
            trends.append(MetricTrend(
                name: "VO₂ Max",
                value: String(format: "%.1f", vo2),
                direction: direction
            ))
        }

        // Walking speed - higher is better (indicates mobility)
        if let speed = current.walkingSpeed {
            let direction = trendDirection(for: walkingSpeedChange, lowerIsBetter: false)
            let kmh = speed * 3.6  // Convert m/s to km/h
            trends.append(MetricTrend(
                name: "Walk Speed",
                value: String(format: "%.1f km/h", kmh),
                direction: direction
            ))
        }

        // Six-minute walk test - higher is better
        if let sixMin = current.sixMinuteWalkDistance {
            let direction = trendDirection(for: sixMinWalkChange, lowerIsBetter: false)
            trends.append(MetricTrend(
                name: "6-Min Walk",
                value: "\(sixMin.wholeNumber) m",
                direction: direction
            ))
        }

        return trends
    }

    /// Determines trend direction for a metric given its change percentage.
    private func trendDirection(for change: Double?, lowerIsBetter: Bool) -> TrendDirection {
        guard let change else { return .stable }
        let threshold = 5.0  // 5% change threshold for activity metrics

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
            Analyze each performance metric individually. For all metrics, HIGHER values \
            indicate better fitness and activity levels. Be specific about which metrics \
            improved and which declined. Keep response under 100 characters.
            """
        ]

        if let steps = current.stepCount {
            let trend = stepCountChange.map { $0 > 0 ? "improved" : ($0 < 0 ? "declined" : "stable") } ?? "stable"
            lines.append("Steps: \(steps.formattedWithCommas)\(stepCountChange.parentheticalChange) [\(trend)]")
        }
        if let dist = current.distanceMeters {
            let km = dist / 1000
            let trend = distanceChange.map { $0 > 0 ? "improved" : ($0 < 0 ? "declined" : "stable") } ?? "stable"
            lines.append("Distance: \(String(format: "%.1f", km)) km\(distanceChange.parentheticalChange) [\(trend)]")
        }
        if let cals = current.activeCalories {
            let trend = caloriesChange.map { $0 > 0 ? "improved" : ($0 < 0 ? "declined" : "stable") } ?? "stable"
            lines.append("Active calories: \(cals.wholeNumber) kcal\(caloriesChange.parentheticalChange) [\(trend)]")
        }
        if let mins = current.exerciseMinutes {
            let trend = exerciseChange.map { $0 > 0 ? "improved" : ($0 < 0 ? "declined" : "stable") } ?? "stable"
            lines.append("Exercise: \(mins.wholeNumber) min\(exerciseChange.parentheticalChange) [\(trend)]")
        }
        if let vo2 = current.vo2Max {
            let trend = vo2MaxChange.map { $0 > 0 ? "improved" : ($0 < 0 ? "declined" : "stable") } ?? "stable"
            lines.append("VO₂ Max: \(String(format: "%.1f", vo2)) ml/kg/min\(vo2MaxChange.parentheticalChange) [\(trend)]")
        }
        if let speed = current.walkingSpeed {
            let kmh = speed * 3.6
            let trend = walkingSpeedChange.map { $0 > 0 ? "improved" : ($0 < 0 ? "declined" : "stable") } ?? "stable"
            lines.append("Walking speed: \(String(format: "%.1f", kmh)) km/h\(walkingSpeedChange.parentheticalChange) [\(trend)]")
        }

        return lines.joined(separator: "\n")
    }

    var metricsDisplay: String {
        var parts: [String] = []
        if let steps = current.stepCount {
            parts.append("\(steps.formattedWithCommas) steps")
        }
        if let cals = current.activeCalories {
            parts.append("\(cals.wholeNumber) cal")
        }
        if let vo2 = current.vo2Max {
            parts.append("VO₂ \(String(format: "%.0f", vo2))")
        }
        return parts.joined(separator: " · ")
    }

    var fallbackShortSummary: String {
        guard let change = stepCountChange else {
            return "Activity data available"
        }
        let absChange = abs(change)
        switch trend {
        case .improving:
            return "Activity up \(absChange.wholeNumber)%"
        case .declining:
            return "Activity down \(absChange.wholeNumber)%"
        case .stable:
            return "Activity stable"
        }
    }

    var fallbackSummary: String {
        switch trend {
        case .improving: return "Your activity levels are increasing."
        case .stable: return "Your activity levels are consistent."
        case .declining: return "Your activity levels have decreased."
        }
    }
}

// MARK: - Number Formatting Helpers

extension Double {
    /// Formats a number with comma separators (e.g., 10,234).
    var formattedWithCommas: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: self)) ?? "\(Int(self))"
    }
}
