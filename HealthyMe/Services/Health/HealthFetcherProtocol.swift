//
//  HealthFetcherProtocol.swift
//  HealthyMe
//
//  Protocol for fetching health data from HealthKit.
//  Each category has its own fetch method returning the appropriate data model.
//

import Foundation

/// Protocol for fetching health metrics from HealthKit.
/// Implementers must provide fetch methods for each health category.
protocol HealthFetcherProtocol: Sendable {

    // MARK: - Heart (Implemented)

    /// Fetch heart data (HR, resting HR, walking HR, HRV) averaged over a date interval.
    func fetchHeartData(for period: DateInterval) async throws -> HeartData

    // MARK: - Sleep (TODO)

    /// Fetch sleep data (total sleep, REM, deep, awake) for a date interval.
    /// TODO: Implement HKCategoryTypeIdentifier.sleepAnalysis queries
    func fetchSleepData(for period: DateInterval) async throws -> SleepData

    // MARK: - Performance (TODO)

    /// Fetch performance data (steps, distance, calories, exercise time) for a date interval.
    /// TODO: Implement stepCount, distanceWalkingRunning, activeEnergyBurned, appleExerciseTime queries
    func fetchPerformanceData(for period: DateInterval) async throws -> PerformanceData

    // MARK: - Vitality (TODO)

    /// Fetch vitality data (body temp, respiratory rate, blood pressure) for a date interval.
    /// TODO: Implement bodyMass, respiratoryRate, oxygenSaturation queries
    func fetchVitalityData(for period: DateInterval) async throws -> VitalityData

    // MARK: - Mindfulness (TODO)

    /// Fetch mindfulness data (total minutes, session count) for a date interval.
    /// TODO: Implement HKCategoryTypeIdentifier.mindfulSession queries
    func fetchMindfulnessData(for period: DateInterval) async throws -> MindfulnessData
}
