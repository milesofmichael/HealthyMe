//
//  MockHealthFetcher.swift
//  HealthyMe
//
//  Mock implementation of HealthFetcherProtocol for demo mode and testing.
//  Returns configurable sample data without requiring HealthKit access.
//

import Foundation

/// Mock health data fetcher that returns sample data.
/// Used for demo mode and unit tests. No HealthKit dependency.
struct MockHealthFetcher: HealthFetcherProtocol {

    // MARK: - Mock Data Sources

    /// Mock data for each category - tests can override these
    var heartData = MockHeartData()
    var sleepData = MockSleepData()
    var performanceData = MockPerformanceData()
    var vitalityData = MockVitalityData()
    var mindfulnessData = MockMindfulnessData()

    /// Optional delay to simulate network/HealthKit latency (seconds)
    var simulatedDelay: Double = 0.3

    // MARK: - HealthFetcherProtocol

    func fetchHeartData(for period: DateInterval) async throws -> HeartData {
        if simulatedDelay > 0 {
            try? await Task.sleep(for: .seconds(simulatedDelay))
        }
        return heartData.toHeartData(for: period)
    }

    func fetchSleepData(for period: DateInterval) async throws -> SleepData {
        if simulatedDelay > 0 {
            try? await Task.sleep(for: .seconds(simulatedDelay))
        }
        return sleepData.toSleepData(for: period)
    }

    func fetchPerformanceData(for period: DateInterval) async throws -> PerformanceData {
        if simulatedDelay > 0 {
            try? await Task.sleep(for: .seconds(simulatedDelay))
        }
        return performanceData.toPerformanceData(for: period)
    }

    func fetchVitalityData(for period: DateInterval) async throws -> VitalityData {
        if simulatedDelay > 0 {
            try? await Task.sleep(for: .seconds(simulatedDelay))
        }
        return vitalityData.toVitalityData(for: period)
    }

    func fetchMindfulnessData(for period: DateInterval) async throws -> MindfulnessData {
        if simulatedDelay > 0 {
            try? await Task.sleep(for: .seconds(simulatedDelay))
        }
        return mindfulnessData.toMindfulnessData(for: period)
    }
}
