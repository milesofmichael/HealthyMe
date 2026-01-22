//
//  MockMindfulnessData.swift
//  HealthyMe
//
//  Mock mindfulness data with healthy defaults for demo mode and unit tests.
//  Tests can override specific properties to test edge cases.
//

import Foundation

/// Mock mindfulness metrics with healthy defaults.
/// Demo mode uses defaults; tests override specific values as needed.
struct MockMindfulnessData {
    /// Total mindful minutes (default: consistent practice)
    var totalMinutes: Double = 15

    /// Number of sessions (default: daily practice)
    var sessionCount: Int = 2

    /// Average session duration in minutes (default: good engagement)
    var averageSessionDuration: Double? = nil  // Computed from total/count if nil

    /// Converts to MindfulnessData model for the given period
    func toMindfulnessData(for period: DateInterval) -> MindfulnessData {
        let avgDuration = averageSessionDuration ?? (sessionCount > 0 ? totalMinutes / Double(sessionCount) : nil)

        return MindfulnessData(
            period: period,
            totalMinutes: totalMinutes,
            sessionCount: sessionCount,
            averageSessionDuration: avgDuration
        )
    }
}
