//
//  HeartData.swift
//  HealthPanda
//
//  Heart health metrics for a time period.
//

import Foundation

/// Heart health metrics averaged over a time period.
struct HeartData: Sendable {
    let period: DateInterval

    /// Average heart rate in BPM (nil if no data)
    let heartRate: Double?

    /// Average resting heart rate in BPM
    let restingHeartRate: Double?

    /// Average blood oxygen percentage (0-100)
    let bloodOxygen: Double?

    /// Average walking heart rate in BPM
    let walkingHeartRate: Double?

    /// Average heart rate variability in milliseconds
    let hrv: Double?

    /// True if we have at least heart rate data (the critical metric)
    var hasCriticalData: Bool {
        heartRate != nil
    }

    /// True if we have any data at all
    var hasAnyData: Bool {
        heartRate != nil || restingHeartRate != nil || bloodOxygen != nil ||
        walkingHeartRate != nil || hrv != nil
    }

    /// Empty data for a period
    static func empty(for period: DateInterval) -> HeartData {
        HeartData(
            period: period,
            heartRate: nil,
            restingHeartRate: nil,
            bloodOxygen: nil,
            walkingHeartRate: nil,
            hrv: nil
        )
    }
}

/// Comparison of heart data between two periods.
struct HeartComparison: Sendable {
    let previous: HeartData
    let current: HeartData

    /// Percentage change in heart rate (positive = increased)
    var heartRateChange: Double? {
        guard let prev = previous.heartRate, let curr = current.heartRate, prev > 0 else {
            return nil
        }
        return ((curr - prev) / prev) * 100
    }

    /// Percentage change in resting heart rate
    var restingHeartRateChange: Double? {
        guard let prev = previous.restingHeartRate, let curr = current.restingHeartRate, prev > 0 else {
            return nil
        }
        return ((curr - prev) / prev) * 100
    }

    /// Percentage change in blood oxygen
    var bloodOxygenChange: Double? {
        guard let prev = previous.bloodOxygen, let curr = current.bloodOxygen, prev > 0 else {
            return nil
        }
        return ((curr - prev) / prev) * 100
    }

    /// Percentage change in HRV (higher is generally better)
    var hrvChange: Double? {
        guard let prev = previous.hrv, let curr = current.hrv, prev > 0 else {
            return nil
        }
        return ((curr - prev) / prev) * 100
    }
}
