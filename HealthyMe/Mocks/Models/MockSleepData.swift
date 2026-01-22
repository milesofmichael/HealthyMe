//
//  MockSleepData.swift
//  HealthyMe
//
//  Mock sleep data with healthy defaults for demo mode and unit tests.
//  Tests can override specific properties to test edge cases.
//

import Foundation

/// Mock sleep metrics with healthy defaults.
/// Demo mode uses defaults; tests override specific values as needed.
struct MockSleepData {
    /// Total sleep in hours (default: within ideal 7-9 hour range)
    var totalHours: Double = 7.5

    /// REM sleep percentage (default: healthy 22%, ideal is 20-25%)
    var remPercent: Double = 0.22

    /// Core (light) sleep percentage (default: 55%)
    var corePercent: Double = 0.55

    /// Deep sleep percentage (default: healthy 18%, ideal is 13-23%)
    var deepPercent: Double = 0.18

    /// Number of awakenings during sleep (default: minimal disruption)
    var awakenings: Int = 2

    /// Sleep efficiency percentage (default: good efficiency)
    var efficiency: Double = 88.0

    /// Time in bed in hours (default: slightly more than sleep time)
    var inBedHours: Double = 8.5

    /// Converts to SleepData model for the given period
    func toSleepData(for period: DateInterval) -> SleepData {
        let totalMinutes = totalHours * 60
        let remMinutes = totalMinutes * remPercent
        let coreMinutes = totalMinutes * corePercent
        let deepMinutes = totalMinutes * deepPercent
        let inBedMinutes = inBedHours * 60

        return SleepData(
            period: period,
            totalSleepMinutes: totalMinutes,
            remMinutes: remMinutes,
            coreMinutes: coreMinutes,
            deepSleepMinutes: deepMinutes,
            inBedMinutes: inBedMinutes,
            sleepEfficiency: efficiency,
            awakeningsCount: awakenings
        )
    }
}
