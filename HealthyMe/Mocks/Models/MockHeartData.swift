//
//  MockHeartData.swift
//  HealthyMe
//
//  Mock heart data with healthy defaults for demo mode and unit tests.
//  Tests can override specific properties to test edge cases.
//

import Foundation

/// Mock heart metrics with healthy defaults.
/// Demo mode uses defaults; tests override specific values as needed.
struct MockHeartData {
    /// Average heart rate in BPM (default: healthy adult at rest/light activity)
    var heartRate: Double = 72

    /// Resting heart rate in BPM (default: good cardiovascular fitness)
    var restingHeartRate: Double = 58

    /// Walking heart rate in BPM (default: moderate exertion)
    var walkingHeartRate: Double = 95

    /// Heart rate variability in milliseconds (default: good recovery/low stress)
    var hrv: Double = 45

    /// Converts to HeartData model for the given period
    func toHeartData(for period: DateInterval) -> HeartData {
        HeartData(
            period: period,
            heartRate: heartRate,
            restingHeartRate: restingHeartRate,
            walkingHeartRate: walkingHeartRate,
            hrv: hrv
        )
    }
}
