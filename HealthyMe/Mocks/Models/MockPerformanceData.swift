//
//  MockPerformanceData.swift
//  HealthyMe
//
//  Mock performance data with healthy defaults for demo mode and unit tests.
//  Tests can override specific properties to test edge cases.
//

import Foundation

/// Mock performance metrics with healthy defaults.
/// Demo mode uses defaults; tests override specific values as needed.
struct MockPerformanceData {
    /// Daily step count (default: above 8000 goal)
    var stepCount: Double = 8432

    /// Distance in kilometers (default: reasonable for step count)
    var distanceKm: Double = 6.2

    /// Active calories burned (default: moderate activity)
    var activeCalories: Double = 320

    /// Exercise minutes (default: above 30 min goal)
    var exerciseMinutes: Double = 35

    /// VO2 max in ml/kg/min (default: good cardiovascular fitness)
    var vo2Max: Double? = 42.5

    /// Walking speed in km/h (default: healthy pace)
    var walkingSpeedKmh: Double = 5.2

    /// Six-minute walk test distance in meters (default: good endurance)
    var sixMinuteWalkDistance: Double? = nil

    /// Converts to PerformanceData model for the given period
    func toPerformanceData(for period: DateInterval) -> PerformanceData {
        PerformanceData(
            period: period,
            stepCount: stepCount,
            distanceMeters: distanceKm * 1000,
            activeCalories: activeCalories,
            exerciseMinutes: exerciseMinutes,
            vo2Max: vo2Max,
            walkingSpeed: walkingSpeedKmh / 3.6,  // Convert km/h to m/s
            sixMinuteWalkDistance: sixMinuteWalkDistance
        )
    }
}
