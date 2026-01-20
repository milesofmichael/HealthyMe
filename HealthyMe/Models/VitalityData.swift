//
//  VitalityData.swift
//  HealthyMe
//
//  Vitality metrics and comparison logic.
//  Tracks body composition, respiratory health, blood oxygen, and temperature baselines.
//

import Foundation

// MARK: - Vitality Data

/// Vital signs and body composition metrics for a time period.
struct VitalityData: Sendable {
    let period: DateInterval
    let bodyMass: Double?                  // kg - weight tracking
    let bodyMassIndex: Double?             // BMI calculated from weight and height
    let respiratoryRate: Double?           // breaths per minute (sleep only)
    let oxygenSaturation: Double?          // SpO2 percentage (0.0-1.0 from HealthKit)
    let wristTemperature: Double?          // °C deviation from baseline (sleep)

    var hasAnyData: Bool {
        bodyMass != nil || bodyMassIndex != nil ||
        respiratoryRate != nil || oxygenSaturation != nil ||
        wristTemperature != nil
    }

    static func empty(for period: DateInterval) -> VitalityData {
        VitalityData(
            period: period,
            bodyMass: nil,
            bodyMassIndex: nil,
            respiratoryRate: nil,
            oxygenSaturation: nil,
            wristTemperature: nil
        )
    }
}

// MARK: - Vitality Comparison

/// Comparison of vitality data between two periods.
struct VitalityComparison: HealthComparison {
    let previous: VitalityData
    let current: VitalityData

    var hasData: Bool { current.hasAnyData }

    // MARK: - Percentage Changes

    /// O(1) - simple nil check and arithmetic.
    private func percentChange(from prev: Double?, to curr: Double?) -> Double? {
        guard let prev, let curr, prev > 0 else { return nil }
        return ((curr - prev) / prev) * 100
    }

    /// Absolute change for metrics where percentage doesn't make sense (e.g., temperature deviation).
    private func absoluteChange(from prev: Double?, to curr: Double?) -> Double? {
        guard let prev, let curr else { return nil }
        return curr - prev
    }

    var bodyMassChange: Double? {
        percentChange(from: previous.bodyMass, to: current.bodyMass)
    }

    var bmiChange: Double? {
        percentChange(from: previous.bodyMassIndex, to: current.bodyMassIndex)
    }

    var respiratoryRateChange: Double? {
        percentChange(from: previous.respiratoryRate, to: current.respiratoryRate)
    }

    var oxygenChange: Double? {
        // Use absolute change for SpO2 since percentages are misleading (95% vs 97%)
        absoluteChange(from: previous.oxygenSaturation, to: current.oxygenSaturation)
    }

    var wristTempChange: Double? {
        // Absolute change for temperature deviation
        absoluteChange(from: previous.wristTemperature, to: current.wristTemperature)
    }

    // MARK: - Per-Metric Trends

    /// Individual trend indicators for each vitality metric.
    /// Vitals are best when stable or within normal ranges.
    var metricTrends: [MetricTrend] {
        var trends: [MetricTrend] = []

        // Body mass - stability is generally good; large changes warrant attention
        if let mass = current.bodyMass {
            let direction = bodyMassTrend()
            let lbs = mass * 2.205  // Convert kg to lbs for US display
            trends.append(MetricTrend(
                name: "Weight",
                value: String(format: "%.1f lbs", lbs),
                direction: direction
            ))
        }

        // BMI - stability within healthy range (18.5-24.9) is best
        if let bmi = current.bodyMassIndex {
            let direction = bmiTrend()
            trends.append(MetricTrend(
                name: "BMI",
                value: String(format: "%.1f", bmi),
                direction: direction
            ))
        }

        // Respiratory rate - 12-20 breaths/min is normal; stability is good
        if let rr = current.respiratoryRate {
            let direction = respiratoryTrend()
            trends.append(MetricTrend(
                name: "Resp Rate",
                value: "\(rr.wholeNumber)/min",
                direction: direction
            ))
        }

        // Oxygen saturation - higher is better (95%+ is normal)
        if let spo2 = current.oxygenSaturation {
            let direction = oxygenTrend()
            let percentage = spo2 * 100  // HealthKit stores as 0.0-1.0
            trends.append(MetricTrend(
                name: "SpO₂",
                value: String(format: "%.0f%%", percentage),
                direction: direction
            ))
        }

        // Wrist temperature deviation - closer to 0 is better (baseline)
        if let temp = current.wristTemperature {
            let direction = temperatureTrend()
            let sign = temp >= 0 ? "+" : ""
            trends.append(MetricTrend(
                name: "Wrist Temp",
                value: "\(sign)\(String(format: "%.1f", temp))°C",
                direction: direction
            ))
        }

        return trends
    }

    // MARK: - Trend Helpers

    /// Body mass trend - large changes (>2%) may warrant attention.
    private func bodyMassTrend() -> TrendDirection {
        guard let change = bodyMassChange else { return .stable }
        if abs(change) < 2.0 { return .stable }
        // Weight changes are context-dependent; mark as stable unless dramatic
        return abs(change) > 5.0 ? .declining : .stable
    }

    /// BMI trend - moving toward healthy range (18.5-24.9) is improving.
    private func bmiTrend() -> TrendDirection {
        guard let current = current.bodyMassIndex,
              let prev = previous.bodyMassIndex else { return .stable }

        let healthyRange = 18.5...24.9
        let wasHealthy = healthyRange.contains(prev)
        let isHealthy = healthyRange.contains(current)

        if !wasHealthy && isHealthy { return .improving }
        if wasHealthy && !isHealthy { return .declining }

        // Moving toward healthy range from outside
        if current < 18.5 && prev < current { return .improving }
        if current > 24.9 && prev > current { return .improving }

        return .stable
    }

    /// Respiratory rate trend - staying within 12-20 is good.
    private func respiratoryTrend() -> TrendDirection {
        guard let rr = current.respiratoryRate else { return .stable }
        if rr >= 12 && rr <= 20 { return .stable }
        return .declining  // Outside normal range
    }

    /// Oxygen saturation trend - higher is better, <94% is concerning.
    private func oxygenTrend() -> TrendDirection {
        guard let spo2 = current.oxygenSaturation else { return .stable }
        let percentage = spo2 * 100

        if percentage >= 95 { return .stable }
        if percentage >= 90 { return .declining }
        return .declining  // Below 90% is serious
    }

    /// Temperature deviation trend - closer to 0 (baseline) is better.
    private func temperatureTrend() -> TrendDirection {
        guard let curr = current.wristTemperature else { return .stable }
        guard let prev = previous.wristTemperature else {
            // No previous data; judge based on absolute deviation
            return abs(curr) < 0.5 ? .stable : (abs(curr) > 1.0 ? .declining : .stable)
        }

        // Moving closer to baseline is improving
        if abs(curr) < abs(prev) { return .improving }
        if abs(curr) > abs(prev) && abs(curr) > 0.5 { return .declining }
        return .stable
    }

    // MARK: - HealthComparison Protocol

    /// Aggregate trend - vitals are best when stable.
    var trend: TrendDirection {
        let trends = metricTrends
        guard !trends.isEmpty else { return .stable }

        let declining = trends.filter { $0.direction == .declining }.count

        // Any declining vital is a concern
        if declining > 0 { return .declining }

        let improving = trends.filter { $0.direction == .improving }.count
        if improving > 0 { return .improving }

        return .stable
    }

    var promptText: String {
        var lines = [
            """
            Analyze these vital signs. Body weight and BMI changes are context-dependent. \
            Respiratory rate should be 12-20/min. SpO₂ should be 95%+. Wrist temp deviation \
            near 0°C is baseline. Keep response under 100 characters.
            """
        ]

        if let mass = current.bodyMass {
            let lbs = mass * 2.205
            lines.append("Weight: \(String(format: "%.1f", lbs)) lbs\(bodyMassChange.parentheticalChange)")
        }
        if let bmi = current.bodyMassIndex {
            let status = bmi < 18.5 ? "underweight" : (bmi > 24.9 ? "overweight" : "healthy")
            lines.append("BMI: \(String(format: "%.1f", bmi)) (\(status))\(bmiChange.parentheticalChange)")
        }
        if let rr = current.respiratoryRate {
            let status = (rr >= 12 && rr <= 20) ? "normal" : "outside normal"
            lines.append("Respiratory: \(rr.wholeNumber)/min (\(status))")
        }
        if let spo2 = current.oxygenSaturation {
            let percentage = spo2 * 100
            let status = percentage >= 95 ? "normal" : "low"
            lines.append("SpO₂: \(String(format: "%.0f", percentage))% (\(status))")
        }
        if let temp = current.wristTemperature {
            let sign = temp >= 0 ? "+" : ""
            lines.append("Wrist temp: \(sign)\(String(format: "%.1f", temp))°C from baseline")
        }

        return lines.joined(separator: "\n")
    }

    var metricsDisplay: String {
        var parts: [String] = []

        if let mass = current.bodyMass {
            let lbs = mass * 2.205
            parts.append("\(String(format: "%.0f", lbs)) lbs")
        }
        if let spo2 = current.oxygenSaturation {
            let percentage = spo2 * 100
            parts.append("SpO₂ \(String(format: "%.0f", percentage))%")
        }
        if let rr = current.respiratoryRate {
            parts.append("\(rr.wholeNumber)/min")
        }

        return parts.joined(separator: " · ")
    }

    var fallbackShortSummary: String {
        switch trend {
        case .improving:
            return "Vitals improving"
        case .declining:
            return "Check vitals"
        case .stable:
            return "Vitals stable"
        }
    }

    var fallbackSummary: String {
        switch trend {
        case .improving:
            return "Your vital signs are showing improvement."
        case .stable:
            return "Your vital signs are within normal ranges."
        case .declining:
            return "Some vital signs may need attention."
        }
    }
}
