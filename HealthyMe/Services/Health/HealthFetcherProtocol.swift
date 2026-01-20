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

    // MARK: - Heart

    /// Fetch heart data (HR, resting HR, walking HR, HRV) averaged over a date interval.
    func fetchHeartData(for period: DateInterval) async throws -> HeartData

    // MARK: - Sleep

    /// Fetch sleep data (total sleep, REM, core, deep, efficiency, awakenings) for a date interval.
    /// Queries HKCategoryTypeIdentifier.sleepAnalysis and aggregates by sleep stage.
    func fetchSleepData(for period: DateInterval) async throws -> SleepData

    // MARK: - Performance

    /// Fetch performance data (steps, distance, calories, exercise time, VO2 max, walking speed,
    /// six-minute walk distance) for a date interval.
    func fetchPerformanceData(for period: DateInterval) async throws -> PerformanceData

    // MARK: - Vitality

    /// Fetch vitality data (body mass, BMI, respiratory rate, SpO2, wrist temperature) for a date interval.
    func fetchVitalityData(for period: DateInterval) async throws -> VitalityData

    // MARK: - Mindfulness

    /// Fetch mindfulness data (total minutes, session count, average duration) for a date interval.
    /// Queries HKCategoryTypeIdentifier.mindfulSession and aggregates session durations.
    func fetchMindfulnessData(for period: DateInterval) async throws -> MindfulnessData
}
