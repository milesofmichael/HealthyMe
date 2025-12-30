//
//  HealthService.swift
//  HealthPanda
//
//  Consolidated health service handling authorization, data fetching,
//  LLM summarization, and caching. Uses actor isolation for thread safety.
//

import HealthKit

/// Central service for all health-related operations.
/// Combines authorization, fetching, summarization, and caching.
actor HealthService: HealthServiceProtocol {

    static let shared = HealthService()

    private let healthStore = HKHealthStore()
    private let fetcher: HealthFetcherProtocol
    private let summarizer: SummaryServiceProtocol
    private let cache: HealthCacheProtocol
    private let logger: LoggerServiceProtocol = LoggerService.shared

    // In-memory cache for current session
    private var summaries: [HealthCategory: CategorySummary] = [:]

    // MARK: - Health Data Type Definitions

    /// Quantity types organized by health category.
    /// Each category only requests permissions for its relevant types.
    private let quantityTypesByCategory: [HealthCategory: [HKQuantityTypeIdentifier]] = [
        .heart: [
            .heartRate,
            .restingHeartRate,
            .oxygenSaturation,
            .walkingHeartRateAverage,
            .heartRateVariabilitySDNN
        ],
        .sleep: [
            // Sleep primarily uses category types, but may include some quantity data
        ],
        .mindfulness: [
            // Mindfulness uses category types only
        ],
        .performance: [
            .stepCount,
            .distanceWalkingRunning,
            .distanceCycling,
            .activeEnergyBurned,
            .appleExerciseTime
        ],
        .vitality: [
            .bodyTemperature,
            .respiratoryRate,
            .bloodPressureSystolic,
            .bloodPressureDiastolic
        ]
    ]

    /// Category types organized by health category.
    /// These represent data with discrete values (e.g., sleep stages).
    private let categoryTypesByCategory: [HealthCategory: [HKCategoryTypeIdentifier]] = [
        .heart: [],
        .sleep: [.sleepAnalysis],
        .mindfulness: [.mindfulSession],
        .performance: [],
        .vitality: []
    ]

    // MARK: - Initialization

    init(
        fetcher: HealthFetcherProtocol = HealthFetcher.shared,
        summarizer: SummaryServiceProtocol = FoundationModelService.shared,
        cache: HealthCacheProtocol = HealthCache.shared
    ) {
        self.fetcher = fetcher
        self.summarizer = summarizer
        self.cache = cache
    }

    // MARK: - HealthServiceProtocol

    nonisolated var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Request authorization for a specific category's health types.
    /// Called lazily when user opens a category tile.
    func requestAuthorization(for category: HealthCategory) async throws -> Bool {
        guard isHealthDataAvailable else {
            logger.warning("HealthKit not available")
            return false
        }

        let types = readTypes(for: category)
        guard !types.isEmpty else {
            logger.debug("No types to request for \(category.rawValue)")
            return true
        }

        return try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: nil, read: types) { success, error in
                if let error {
                    self.logger.error("HealthKit auth failed for \(category.rawValue): \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    self.logger.info("HealthKit auth for \(category.rawValue): \(success)")
                    continuation.resume(returning: success)
                }
            }
        }
    }

    /// Check if authorization has been requested for a category's types.
    func checkAuthorizationStatus(for category: HealthCategory) async -> HealthAuthorizationStatus {
        guard isHealthDataAvailable else { return .unavailable }

        let types = readTypes(for: category)
        guard !types.isEmpty else { return .authorized }

        do {
            let status = try await healthStore.statusForAuthorizationRequest(
                toShare: [],
                read: types
            )

            switch status {
            case .shouldRequest:
                logger.debug("Authorization should be requested for \(category.rawValue)")
                return .notDetermined
            case .unnecessary:
                logger.debug("Authorization already requested for \(category.rawValue)")
                return .authorized
            case .unknown:
                logger.warning("Authorization status unknown for \(category.rawValue)")
                return .notDetermined
            @unknown default:
                return .notDetermined
            }
        } catch {
            logger.error("Failed to check auth status for \(category.rawValue): \(error.localizedDescription)")
            return .notDetermined
        }
    }

    /// Get cached summary for a category, or nil if not cached.
    func getCachedSummary(for category: HealthCategory) async -> CategorySummary? {
        // Check in-memory first
        if let summary = summaries[category], !summary.isStale {
            return summary
        }

        // Then check persistent cache
        if let summary = await cache.getSummary(for: category), !summary.isStale {
            summaries[category] = summary
            return summary
        }

        return nil
    }

    /// Refresh data for a specific category and generate new summary.
    func refreshCategory(_ category: HealthCategory) async -> CategorySummary {
        logger.info("Refreshing \(category.rawValue) data")

        switch category {
        case .heart:
            return await refreshHeart()
        case .sleep, .mindfulness, .performance, .vitality:
            // Placeholder for future implementation
            // For now, return a summary indicating data is not yet available
            logger.info("\(category.rawValue) category not yet implemented")
            let summary = CategorySummary.noData(for: category)
            await saveSummary(summary)
            return summary
        }
    }

    // MARK: - Private Helpers

    /// Build the set of HKObjectTypes for a specific category.
    /// Uses Sets for O(1) lookup and deduplication.
    private func readTypes(for category: HealthCategory) -> Set<HKObjectType> {
        var types = Set<HKObjectType>()

        // Add quantity types for this category
        if let identifiers = quantityTypesByCategory[category] {
            for identifier in identifiers {
                if let type = HKQuantityType.quantityType(forIdentifier: identifier) {
                    types.insert(type)
                }
            }
        }

        // Add category types for this category
        if let identifiers = categoryTypesByCategory[category] {
            for identifier in identifiers {
                if let type = HKCategoryType.categoryType(forIdentifier: identifier) {
                    types.insert(type)
                }
            }
        }

        logger.debug("Category \(category.rawValue) has \(types.count) health types")
        return types
    }

    /// Refresh heart category data specifically.
    private func refreshHeart() async -> CategorySummary {
        do {
            // Fetch data for both periods concurrently
            async let lastMonthData = fetcher.fetchHeartData(for: .lastMonth)
            async let thisMonthData = fetcher.fetchHeartData(for: .thisMonth)

            let lastMonth = try await lastMonthData
            let thisMonth = try await thisMonthData

            // Check data availability
            guard thisMonth.hasAnyData else {
                logger.warning("No heart data available")
                let summary = CategorySummary.noData(for: .heart)
                await saveSummary(summary)
                return summary
            }

            guard thisMonth.hasCriticalData else {
                logger.warning("Missing critical heart data")
                let summary = CategorySummary.missingCritical(for: .heart)
                await saveSummary(summary)
                return summary
            }

            // Generate LLM summary
            let comparison = HeartComparison(previous: lastMonth, current: thisMonth)
            let healthSummary = try await summarizer.generateHeartSummary(comparison: comparison)

            let summary = CategorySummary(
                category: .heart,
                status: .ready,
                smallSummary: healthSummary.small,
                largeSummary: healthSummary.large,
                lastUpdated: Date()
            )

            await saveSummary(summary)
            logger.info("Heart summary generated successfully")
            return summary

        } catch {
            logger.error("Failed to refresh heart data: \(error.localizedDescription)")
            // Return cached or placeholder on error
            if let cached = summaries[.heart] {
                return cached
            }
            return CategorySummary.noData(for: .heart)
        }
    }

    /// Save summary to both in-memory and persistent cache.
    private func saveSummary(_ summary: CategorySummary) async {
        summaries[summary.category] = summary
        await cache.saveSummary(summary)
    }
}
