//
//  HealthFetcher.swift
//  HealthPanda
//
//  Fetches health data from HealthKit.
//

import HealthKit

final class HealthFetcher: HealthFetcherProtocol {

    static let shared = HealthFetcher()

    private let healthStore = HKHealthStore()
    private let logger: LoggerServiceProtocol = LoggerService.shared

    // Heart rate unit: count/min (beats per minute)
    // Static to avoid compounding on each call
    private static let bpmUnit = HKUnit.count().unitDivided(by: .minute())

    func fetchHeartData(for period: DateInterval) async throws -> HeartData {
        // Fetch all metrics concurrently
        async let heartRate = fetchAverage(for: .heartRate, unit: Self.bpmUnit, period: period)
        async let restingHR = fetchAverage(for: .restingHeartRate, unit: Self.bpmUnit, period: period)
        async let bloodOxygen = fetchAverage(for: .oxygenSaturation, unit: .percent(), period: period)
        async let walkingHR = fetchAverage(for: .walkingHeartRateAverage, unit: Self.bpmUnit, period: period)
        async let hrv = fetchAverage(for: .heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), period: period)

        return HeartData(
            period: period,
            heartRate: try await heartRate,
            restingHeartRate: try await restingHR,
            bloodOxygen: try await bloodOxygen.map { $0 * 100 }, // Convert to percentage
            walkingHeartRate: try await walkingHR,
            hrv: try await hrv
        )
    }

    // MARK: - Private

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

// MARK: - Date Helpers

extension DateInterval {
    /// Last calendar month
    static var lastMonth: DateInterval {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfThisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfThisMonth) else {
            return DateInterval(start: now, duration: 0)
        }
        return DateInterval(start: startOfLastMonth, end: startOfThisMonth)
    }

    /// Current calendar month (up to now)
    static var thisMonth: DateInterval {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfThisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            return DateInterval(start: now, duration: 0)
        }
        return DateInterval(start: startOfThisMonth, end: now)
    }
}
