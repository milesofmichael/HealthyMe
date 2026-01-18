//
//  HealthFetcher.swift
//  HealthPanda
//
//  Fetches health data from HealthKit.
//  Heart category is fully implemented; other categories have stub implementations.
//

import HealthKit

final class HealthFetcher: HealthFetcherProtocol {

    static let shared = HealthFetcher()

    private let healthStore = HKHealthStore()
    private let logger: LoggerServiceProtocol = LoggerService.shared

    // MARK: - Units (static to avoid recreating)

    private static let bpmUnit = HKUnit.count().unitDivided(by: .minute())
    private static let countUnit = HKUnit.count()
    private static let meterUnit = HKUnit.meter()
    private static let calorieUnit = HKUnit.kilocalorie()
    private static let minuteUnit = HKUnit.minute()

    // MARK: - Heart (Implemented)

    func fetchHeartData(for period: DateInterval) async throws -> HeartData {
        logger.debug("Fetching heart data for \(period.start) to \(period.end)")

        // Fetch all heart metrics concurrently for optimal performance
        async let heartRate = fetchAverage(for: .heartRate, unit: Self.bpmUnit, period: period)
        async let restingHR = fetchAverage(for: .restingHeartRate, unit: Self.bpmUnit, period: period)
        async let walkingHR = fetchAverage(for: .walkingHeartRateAverage, unit: Self.bpmUnit, period: period)
        async let hrv = fetchAverage(for: .heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), period: period)

        return HeartData(
            period: period,
            heartRate: try await heartRate,
            restingHeartRate: try await restingHR,
            walkingHeartRate: try await walkingHR,
            hrv: try await hrv
        )
    }

    // MARK: - Sleep (Stub)

    func fetchSleepData(for period: DateInterval) async throws -> SleepData {
        // TODO: Implement sleep data fetching
        // 1. Query HKCategoryTypeIdentifier.sleepAnalysis
        // 2. Filter samples by HKCategoryValueSleepAnalysis cases:
        //    - .asleepREM, .asleepCore, .asleepDeep for sleep stages
        //    - .inBed for total time in bed
        //    - .awake for awakenings
        // 3. Sum durations for each stage
        // 4. Calculate sleep efficiency: (total asleep / time in bed) * 100
        logger.warning("Sleep data fetching not yet implemented")
        return SleepData.empty(for: period)
    }

    // MARK: - Performance (Stub)

    func fetchPerformanceData(for period: DateInterval) async throws -> PerformanceData {
        // TODO: Implement performance data fetching
        // Use fetchSum() for cumulative metrics, fetchAverage() for rates
        // Metrics to implement:
        // - stepCount: fetchSum(for: .stepCount, unit: .count())
        // - distanceWalkingRunning: fetchSum(for: .distanceWalkingRunning, unit: .meter())
        // - activeEnergyBurned: fetchSum(for: .activeEnergyBurned, unit: .kilocalorie())
        // - appleExerciseTime: fetchSum(for: .appleExerciseTime, unit: .minute())
        // - vo2Max: fetchAverage(for: .vo2Max, unit: ml/(kg·min))
        // - walkingSpeed: fetchAverage(for: .walkingSpeed, unit: m/s)
        logger.warning("Performance data fetching not yet implemented")
        return PerformanceData.empty(for: period)
    }

    // MARK: - Vitality (Stub)

    func fetchVitalityData(for period: DateInterval) async throws -> VitalityData {
        // TODO: Implement vitality data fetching
        // Metrics to implement:
        // - bodyMass: fetchAverage(for: .bodyMass, unit: .pound() or .gramUnit(with: .kilo))
        // - bodyMassIndex: fetchAverage(for: .bodyMassIndex, unit: .count())
        // - respiratoryRate: fetchAverage(for: .respiratoryRate, unit: .count().unitDivided(by: .minute()))
        // - oxygenSaturation: fetchAverage(for: .oxygenSaturation, unit: .percent())
        // - appleSleepingWristTemperature: fetchAverage(for: .appleSleepingWristTemperature, unit: .degreeCelsius())
        logger.warning("Vitality data fetching not yet implemented")
        return VitalityData.empty(for: period)
    }

    // MARK: - Mindfulness (Stub)

    func fetchMindfulnessData(for period: DateInterval) async throws -> MindfulnessData {
        // TODO: Implement mindfulness data fetching
        // 1. Query HKCategoryTypeIdentifier.mindfulSession
        // 2. Count number of sessions in period
        // 3. Sum duration of all sessions
        // 4. Calculate average session duration
        logger.warning("Mindfulness data fetching not yet implemented")
        return MindfulnessData.empty(for: period)
    }

    // MARK: - Private Helpers

    /// Fetches the average value for a quantity type over a period.
    /// Returns nil if no samples exist.
    private func fetchAverage(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        period: DateInterval
    ) async throws -> Double? {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            logger.error("Invalid quantity type: \(identifier.rawValue)")
            return nil
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: period.start,
            end: period.end,
            options: .strictStartDate
        )

        // Use statistics query for efficient averaging
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, statistics, error in
                if let error {
                    self.logger.error("Stats query failed for \(identifier.rawValue): \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }

                guard let average = statistics?.averageQuantity() else {
                    self.logger.debug("No data for \(identifier.rawValue) in period")
                    continuation.resume(returning: nil)
                    return
                }

                let value = average.doubleValue(for: unit)
                self.logger.debug("\(identifier.rawValue) average: \(value)")
                continuation.resume(returning: value)
            }

            healthStore.execute(query)
        }
    }
}

// MARK: - TimeSpan

/// Represents comparison timespan for health summaries.
/// Each case defines a "current" period and a "previous" period for comparison.
/// Uses completed periods only (yesterday vs day before, etc.) for more accurate trends.
enum TimeSpan: String, CaseIterable, Sendable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"

    /// Human-readable description of what's being compared.
    var comparisonDescription: String {
        switch self {
        case .daily: return "Yesterday vs Day Before"
        case .weekly: return "Last Week vs 2 Weeks Ago"
        case .monthly: return "Last Month vs 2 Months Ago"
        }
    }

    /// SF Symbol icon for this timespan.
    var icon: String {
        switch self {
        case .daily: return "sun.max"
        case .weekly: return "calendar.badge.clock"
        case .monthly: return "calendar"
        }
    }

    /// Current period for this timespan (uses completed periods for accuracy).
    var currentPeriod: DateInterval {
        switch self {
        case .daily: return .yesterday
        case .weekly: return .lastWeek
        case .monthly: return .lastMonth
        }
    }

    /// Previous period for comparison.
    var previousPeriod: DateInterval {
        switch self {
        case .daily: return .dayBeforeYesterday
        case .weekly: return .twoWeeksAgo
        case .monthly: return .twoMonthsAgo
        }
    }
}

// MARK: - Date Helpers

extension DateInterval {
    /// Yesterday (full day).
    static var yesterday: DateInterval {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        guard let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) else {
            return DateInterval(start: now, duration: 0)
        }
        return DateInterval(start: startOfYesterday, end: startOfToday)
    }

    /// Day before yesterday (full day).
    static var dayBeforeYesterday: DateInterval {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        guard let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday),
              let startOfDayBefore = calendar.date(byAdding: .day, value: -2, to: startOfToday) else {
            return DateInterval(start: now, duration: 0)
        }
        return DateInterval(start: startOfDayBefore, end: startOfYesterday)
    }

    /// Last week (full week).
    static var lastWeek: DateInterval {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfThisWeek = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        ),
              let startOfLastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: startOfThisWeek) else {
            return DateInterval(start: now, duration: 0)
        }
        return DateInterval(start: startOfLastWeek, end: startOfThisWeek)
    }

    /// Two weeks ago (full week).
    static var twoWeeksAgo: DateInterval {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfThisWeek = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        ),
              let startOfLastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: startOfThisWeek),
              let startOfTwoWeeksAgo = calendar.date(byAdding: .weekOfYear, value: -2, to: startOfThisWeek) else {
            return DateInterval(start: now, duration: 0)
        }
        return DateInterval(start: startOfTwoWeeksAgo, end: startOfLastWeek)
    }

    /// Last calendar month (full month).
    static var lastMonth: DateInterval {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfThisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfThisMonth) else {
            return DateInterval(start: now, duration: 0)
        }
        return DateInterval(start: startOfLastMonth, end: startOfThisMonth)
    }

    /// Two months ago (full month).
    static var twoMonthsAgo: DateInterval {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfThisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfThisMonth),
              let startOfTwoMonthsAgo = calendar.date(byAdding: .month, value: -2, to: startOfThisMonth) else {
            return DateInterval(start: now, duration: 0)
        }
        return DateInterval(start: startOfTwoMonthsAgo, end: startOfLastMonth)
    }
}
