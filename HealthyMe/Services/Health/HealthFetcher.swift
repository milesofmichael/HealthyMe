//
//  HealthFetcher.swift
//  HealthyMe
//
//  Fetches health data from HealthKit.
//  Implements all category fetchers: Heart, Sleep, Performance, Vitality, Mindfulness.
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
    private static let kgUnit = HKUnit.gramUnit(with: .kilo)
    private static let percentUnit = HKUnit.percent()
    private static let celsiusUnit = HKUnit.degreeCelsius()
    private static let meterPerSecondUnit = HKUnit.meter().unitDivided(by: .second())
    private static let vo2MaxUnit = HKUnit.literUnit(with: .milli).unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute()))

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

    // MARK: - Sleep

    func fetchSleepData(for period: DateInterval) async throws -> SleepData {
        logger.debug("Fetching sleep data for \(period.start) to \(period.end)")

        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            logger.error("Sleep analysis type not available")
            return SleepData.empty(for: period)
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: period.start,
            end: period.end,
            options: .strictStartDate
        )

        let samples = try await fetchCategorySamples(type: sleepType, predicate: predicate)

        // Aggregate sleep stages by type
        // O(n) where n = number of sleep samples, optimal for this operation
        var remMinutes: Double = 0
        var coreMinutes: Double = 0
        var deepMinutes: Double = 0
        var inBedMinutes: Double = 0
        var awakeningsCount: Int = 0

        for sample in samples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate) / 60.0  // Convert to minutes

            switch sample.value {
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                remMinutes += duration
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                coreMinutes += duration
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                deepMinutes += duration
            case HKCategoryValueSleepAnalysis.inBed.rawValue:
                inBedMinutes += duration
            case HKCategoryValueSleepAnalysis.awake.rawValue:
                awakeningsCount += 1
            default:
                // Legacy asleep values or unspecified stages add to core
                if sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue {
                    coreMinutes += duration
                }
            }
        }

        let totalAsleep = remMinutes + coreMinutes + deepMinutes

        // Calculate sleep efficiency: (time asleep / time in bed) * 100
        let efficiency: Double? = inBedMinutes > 0 ? (totalAsleep / inBedMinutes) * 100 : nil

        logger.debug("Sleep: \(totalAsleep) min total, \(efficiency ?? 0)% efficiency, \(awakeningsCount) awakenings")

        return SleepData(
            period: period,
            totalSleepMinutes: totalAsleep > 0 ? totalAsleep : nil,
            remMinutes: remMinutes > 0 ? remMinutes : nil,
            coreMinutes: coreMinutes > 0 ? coreMinutes : nil,
            deepSleepMinutes: deepMinutes > 0 ? deepMinutes : nil,
            inBedMinutes: inBedMinutes > 0 ? inBedMinutes : nil,
            sleepEfficiency: efficiency,
            awakeningsCount: awakeningsCount > 0 ? awakeningsCount : nil
        )
    }

    // MARK: - Performance

    func fetchPerformanceData(for period: DateInterval) async throws -> PerformanceData {
        logger.debug("Fetching performance data for \(period.start) to \(period.end)")

        // Fetch all performance metrics concurrently
        // Cumulative metrics use fetchSum(), rate metrics use fetchAverage()
        async let steps = fetchSum(for: .stepCount, unit: Self.countUnit, period: period)
        async let distance = fetchSum(for: .distanceWalkingRunning, unit: Self.meterUnit, period: period)
        async let calories = fetchSum(for: .activeEnergyBurned, unit: Self.calorieUnit, period: period)
        async let exercise = fetchSum(for: .appleExerciseTime, unit: Self.minuteUnit, period: period)
        async let vo2 = fetchAverage(for: .vo2Max, unit: Self.vo2MaxUnit, period: period)
        async let speed = fetchAverage(for: .walkingSpeed, unit: Self.meterPerSecondUnit, period: period)
        async let sixMinWalk = fetchAverage(for: .sixMinuteWalkTestDistance, unit: Self.meterUnit, period: period)

        return PerformanceData(
            period: period,
            stepCount: try await steps,
            distanceMeters: try await distance,
            activeCalories: try await calories,
            exerciseMinutes: try await exercise,
            vo2Max: try await vo2,
            walkingSpeed: try await speed,
            sixMinuteWalkDistance: try await sixMinWalk
        )
    }

    // MARK: - Vitality

    func fetchVitalityData(for period: DateInterval) async throws -> VitalityData {
        logger.debug("Fetching vitality data for \(period.start) to \(period.end)")

        // Fetch all vitality metrics concurrently
        async let mass = fetchAverage(for: .bodyMass, unit: Self.kgUnit, period: period)
        async let bmi = fetchAverage(for: .bodyMassIndex, unit: Self.countUnit, period: period)
        async let respRate = fetchAverage(for: .respiratoryRate, unit: Self.bpmUnit, period: period)
        async let spo2 = fetchAverage(for: .oxygenSaturation, unit: Self.percentUnit, period: period)
        async let wristTemp = fetchAverage(for: .appleSleepingWristTemperature, unit: Self.celsiusUnit, period: period)

        return VitalityData(
            period: period,
            bodyMass: try await mass,
            bodyMassIndex: try await bmi,
            respiratoryRate: try await respRate,
            oxygenSaturation: try await spo2,
            wristTemperature: try await wristTemp
        )
    }

    // MARK: - Mindfulness

    func fetchMindfulnessData(for period: DateInterval) async throws -> MindfulnessData {
        logger.debug("Fetching mindfulness data for \(period.start) to \(period.end)")

        guard let mindfulType = HKCategoryType.categoryType(forIdentifier: .mindfulSession) else {
            logger.error("Mindful session type not available")
            return MindfulnessData.empty(for: period)
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: period.start,
            end: period.end,
            options: .strictStartDate
        )

        let samples = try await fetchCategorySamples(type: mindfulType, predicate: predicate)

        // O(n) aggregation of mindfulness sessions
        var totalMinutes: Double = 0
        let sessionCount = samples.count

        for sample in samples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate) / 60.0
            totalMinutes += duration
        }

        // Calculate average session duration
        let avgDuration: Double? = sessionCount > 0 ? totalMinutes / Double(sessionCount) : nil

        logger.debug("Mindfulness: \(totalMinutes) min across \(sessionCount) sessions")

        return MindfulnessData(
            period: period,
            totalMinutes: totalMinutes > 0 ? totalMinutes : nil,
            sessionCount: sessionCount > 0 ? sessionCount : nil,
            averageSessionDuration: avgDuration
        )
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

    /// Fetches the sum of values for a quantity type over a period.
    /// Used for cumulative metrics like steps, distance, calories.
    private func fetchSum(
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

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    self.logger.error("Sum query failed for \(identifier.rawValue): \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }

                guard let sum = statistics?.sumQuantity() else {
                    self.logger.debug("No sum data for \(identifier.rawValue) in period")
                    continuation.resume(returning: nil)
                    return
                }

                let value = sum.doubleValue(for: unit)
                self.logger.debug("\(identifier.rawValue) sum: \(value)")
                continuation.resume(returning: value)
            }

            healthStore.execute(query)
        }
    }

    /// Fetches category samples (e.g., sleep, mindfulness) for a given type and predicate.
    private func fetchCategorySamples(
        type: HKCategoryType,
        predicate: NSPredicate
    ) async throws -> [HKCategorySample] {
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error {
                    self.logger.error("Category query failed: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }

                let categorySamples = samples as? [HKCategorySample] ?? []
                self.logger.debug("Fetched \(categorySamples.count) category samples")
                continuation.resume(returning: categorySamples)
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
