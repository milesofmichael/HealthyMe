//
//  HealthService.swift
//  HealthPanda
//
//  Central service for health data operations.
//  Handles authorization, fetching, summarization, and caching.
//

import HealthKit

enum HealthServiceError: Error {
    case categoryNotImplemented
}

actor HealthService: HealthServiceProtocol {

    static let shared = HealthService()

    private let healthStore = HKHealthStore()
    private let fetcher: HealthFetcherProtocol
    private let summarizer: SummaryServiceProtocol
    private let cache: HealthCacheProtocol
    private let logger: LoggerServiceProtocol = LoggerService.shared

    // In-memory cache for current session
    private var categorySummaries: [HealthCategory: CategorySummary] = [:]

    // MARK: - Health Data Type Definitions

    private let quantityTypesByCategory: [HealthCategory: [HKQuantityTypeIdentifier]] = [
        .heart: [.heartRate, .restingHeartRate, .oxygenSaturation,
                 .walkingHeartRateAverage, .heartRateVariabilitySDNN],
        .sleep: [],
        .mindfulness: [],
        .performance: [.stepCount, .distanceWalkingRunning, .distanceCycling,
                       .activeEnergyBurned, .appleExerciseTime],
        .vitality: [.bodyTemperature, .respiratoryRate,
                    .bloodPressureSystolic, .bloodPressureDiastolic]
    ]

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
            logger.warning("HealthKit not available on this device")
            return false
        }

        let types = readTypes(for: category)
        guard !types.isEmpty else {
            logger.debug("No health types to request for \(category.rawValue)")
            return true
        }

        logger.info("Requesting HealthKit authorization for \(category.rawValue) (\(types.count) types)")

        return try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: nil, read: types) { success, error in
                if let error {
                    self.logger.error("HealthKit auth failed for \(category.rawValue): \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    self.logger.info("HealthKit auth completed for \(category.rawValue): \(success ? "granted" : "denied")")
                    continuation.resume(returning: success)
                }
            }
        }
    }

    /// Check if authorization has been requested for a category's types.
    func checkAuthorizationStatus(for category: HealthCategory) async -> HealthAuthorizationStatus {
        guard isHealthDataAvailable else {
            logger.debug("HealthKit unavailable, returning .unavailable status")
            return .unavailable
        }

        let types = readTypes(for: category)
        guard !types.isEmpty else {
            logger.debug("No types for \(category.rawValue), returning .authorized")
            return .authorized
        }

        do {
            let status = try await healthStore.statusForAuthorizationRequest(toShare: [], read: types)
            switch status {
            case .shouldRequest:
                logger.debug("Authorization should be requested for \(category.rawValue)")
                return .notDetermined
            case .unnecessary:
                logger.debug("Authorization already granted for \(category.rawValue)")
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
    /// O(1) dictionary lookup for in-memory cache.
    func getCachedSummary(for category: HealthCategory) async -> CategorySummary? {
        // Check in-memory cache first (O(1) lookup)
        if let summary = categorySummaries[category], !summary.isStale {
            logger.debug("Found fresh in-memory summary for \(category.rawValue)")
            return summary
        }

        // Fall back to persistent cache
        if let summary = await cache.getSummary(for: category), !summary.isStale {
            logger.debug("Found fresh persistent cache for \(category.rawValue)")
            categorySummaries[category] = summary
            return summary
        }

        logger.debug("No cached summary found for \(category.rawValue)")
        return nil
    }

    /// Refresh data for a specific category and generate new summary.
    func refreshCategory(_ category: HealthCategory) async -> CategorySummary {
        logger.info("Refreshing \(category.rawValue) data")

        let summary: CategorySummary
        switch category {
        case .heart:
            summary = await refreshCategoryData(for: category, timeSpan: .monthly)
        case .sleep, .mindfulness, .performance, .vitality:
            // Placeholder for future implementation
            logger.info("\(category.rawValue) category not yet implemented")
            summary = CategorySummary.noData(for: category)
        }

        await saveCategorySummary(summary)
        logger.info("Saved summary for \(category.rawValue)")
        return summary
    }

    /// Fetch timespan summaries for a category concurrently.
    /// Uses TaskGroup to fetch daily, weekly, and monthly data in parallel.
    /// Results stream back to UI as they complete for progressive loading.
    func fetchTimespanSummaries(
        for category: HealthCategory,
        onUpdate: @escaping @MainActor (TimeSpan, SummaryLoadingState) -> Void
    ) async {
        logger.info("Fetching \(category.rawValue) timespan summaries concurrently")

        // Signal loading for all timespans upfront
        for timeSpan in TimeSpan.allCases {
            await MainActor.run { onUpdate(timeSpan, .loading) }
        }

        // Fetch all timespans concurrently using TaskGroup
        // O(n) where n = number of timespans (3), runs in parallel
        await withTaskGroup(of: (TimeSpan, SummaryLoadingState).self) { group in
            for timeSpan in TimeSpan.allCases {
                group.addTask {
                    await self.fetchSingleTimespan(category: category, timeSpan: timeSpan)
                }
            }

            // Stream results to main thread as they complete
            for await (timeSpan, state) in group {
                await MainActor.run { onUpdate(timeSpan, state) }
            }
        }

        logger.info("Completed all \(category.rawValue) timespan summaries")
    }

    // MARK: - Private - Data Fetching

    /// Fetches data for a single timespan and generates summary.
    /// Checks cache first for O(1) retrieval when available.
    private func fetchSingleTimespan(
        category: HealthCategory,
        timeSpan: TimeSpan
    ) async -> (TimeSpan, SummaryLoadingState) {
        // Check cache first for fast retrieval
        if let cached = await cache.getTimespanSummary(for: category, timeSpan: timeSpan) {
            logger.debug("Cache hit for \(category.rawValue) \(timeSpan.rawValue)")
            return (timeSpan, .loaded(cached))
        }

        logger.debug("Cache miss, fetching \(category.rawValue) \(timeSpan.rawValue) from HealthKit")

        do {
            let comparison = try await fetchComparison(for: category, timeSpan: timeSpan)

            guard comparison.hasData else {
                logger.debug("No data for \(category.rawValue) \(timeSpan.rawValue)")
                return (timeSpan, .loaded(.noData(for: timeSpan)))
            }

            let summary = try await summarizer.generateSummary(
                comparison: comparison,
                timeSpan: timeSpan
            )

            // Cache the result for future use
            await cache.saveTimespanSummary(summary, for: category)
            logger.debug("Generated and cached \(category.rawValue) \(timeSpan.rawValue) summary")

            return (timeSpan, .loaded(summary))
        } catch {
            logger.error("Failed \(category.rawValue) \(timeSpan.rawValue): \(error.localizedDescription)")
            return (timeSpan, .failed)
        }
    }

    /// Fetches comparison data for a category and timespan.
    /// Fetches current and previous periods concurrently for efficiency.
    private func fetchComparison(
        for category: HealthCategory,
        timeSpan: TimeSpan
    ) async throws -> any HealthComparison {
        switch category {
        case .heart:
            // Fetch both periods concurrently for better performance
            async let current = fetcher.fetchHeartData(for: timeSpan.currentPeriod)
            async let previous = fetcher.fetchHeartData(for: timeSpan.previousPeriod)
            return HeartComparison(previous: try await previous, current: try await current)

        case .sleep, .mindfulness, .performance, .vitality:
            // Future: Add fetchers for other categories
            throw HealthServiceError.categoryNotImplemented
        }
    }

    /// Refresh category data for home screen tile display.
    /// Uses the LLM-generated shortSummary for the tile instead of just metrics.
    private func refreshCategoryData(
        for category: HealthCategory,
        timeSpan: TimeSpan
    ) async -> CategorySummary {
        do {
            let comparison = try await fetchComparison(for: category, timeSpan: timeSpan)

            guard comparison.hasData else {
                logger.warning("No \(category.rawValue) data available")
                return CategorySummary.noData(for: category)
            }

            let timespanSummary = try await summarizer.generateSummary(
                comparison: comparison,
                timeSpan: timeSpan
            )

            // Cache the timespan summary for reuse in detail view
            await cache.saveTimespanSummary(timespanSummary, for: category)

            logger.info("Generated \(category.rawValue) summary successfully")
            return CategorySummary(
                category: category,
                status: .ready,
                smallSummary: timespanSummary.shortSummary,
                largeSummary: timespanSummary.summaryText,
                lastUpdated: Date()
            )
        } catch {
            logger.error("Failed to refresh \(category.rawValue): \(error.localizedDescription)")
            return categorySummaries[category] ?? CategorySummary.noData(for: category)
        }
    }

    // MARK: - Private - Helpers

    /// Build the set of HKObjectTypes for a specific category.
    /// Uses Set for O(1) lookup and automatic deduplication.
    private func readTypes(for category: HealthCategory) -> Set<HKObjectType> {
        var types = Set<HKObjectType>()

        // Add quantity types for this category
        if let identifiers = quantityTypesByCategory[category] {
            for id in identifiers {
                if let type = HKQuantityType.quantityType(forIdentifier: id) {
                    types.insert(type)
                }
            }
        }

        // Add category types for this category
        if let identifiers = categoryTypesByCategory[category] {
            for id in identifiers {
                if let type = HKCategoryType.categoryType(forIdentifier: id) {
                    types.insert(type)
                }
            }
        }

        logger.debug("Category \(category.rawValue) has \(types.count) health types")
        return types
    }

    /// Save summary to both in-memory and persistent cache.
    private func saveCategorySummary(_ summary: CategorySummary) async {
        categorySummaries[summary.category] = summary
        await cache.saveSummary(summary)
    }
}
