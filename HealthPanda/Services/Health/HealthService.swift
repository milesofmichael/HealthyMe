//
//  HealthService.swift
//  HealthPanda
//
//  Central service for health data operations.
//  Handles authorization, fetching, summarization, and caching.
//
//  Key flows:
//  1. refreshAllCategories() - Monolith function for app launch and pull-to-refresh
//  2. refreshCategory() - Single category refresh (used by first-permission edge case)
//  3. fetchTimespanSummaries() - Concurrent fetch of daily/weekly/monthly for detail view
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

    // In-memory cache for current session (O(1) lookup)
    private var categorySummaries: [HealthCategory: CategorySummary] = [:]

    // Track which categories are currently being refreshed (prevents duplicate work)
    private var refreshingCategories: Set<HealthCategory> = []

    // MARK: - Health Data Type Definitions

    private let quantityTypesByCategory: [HealthCategory: [HKQuantityTypeIdentifier]] = [
        .heart: [.heartRate, .restingHeartRate,
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
    /// Used for single-category refresh (e.g., first-time permission grant).
    func refreshCategory(_ category: HealthCategory) async -> CategorySummary {
        logger.info("Refreshing \(category.rawValue) data")

        // Prevent duplicate refreshes for the same category
        guard !refreshingCategories.contains(category) else {
            logger.debug("\(category.rawValue) already refreshing, returning cached")
            return categorySummaries[category] ?? CategorySummary.noData(for: category)
        }
        refreshingCategories.insert(category)
        defer { refreshingCategories.remove(category) }

        let summary = await refreshCategoryData(for: category, timeSpan: .monthly)
        await saveCategorySummary(summary)
        logger.info("Saved summary for \(category.rawValue)")
        return summary
    }

    /// Refresh all authorized categories concurrently.
    /// This is the unified entry point for app launch and pull-to-refresh.
    /// Flow:
    /// 1. For each category, check authorization
    /// 2. If authorized, immediately return cached summary (fast UI)
    /// 3. Then check if cache is stale; if so, fetch fresh data in background
    /// 4. Update UI via callback as each category completes
    func refreshAllCategories(
        onCategoryUpdate: @escaping @MainActor (HealthCategory, CategorySummary) -> Void
    ) async {
        logger.info("Starting monolith refresh for all categories")

        await withTaskGroup(of: Void.self) { group in
            for category in HealthCategory.allCases {
                group.addTask {
                    await self.refreshSingleCategoryWithCallback(
                        category,
                        onUpdate: onCategoryUpdate
                    )
                }
            }
        }

        logger.info("Completed monolith refresh for all categories")
    }

    /// Refresh a single category: show cached first, then refresh if stale.
    private func refreshSingleCategoryWithCallback(
        _ category: HealthCategory,
        onUpdate: @escaping @MainActor (HealthCategory, CategorySummary) -> Void
    ) async {
        // Step 1: Check authorization
        let authStatus = await checkAuthorizationStatus(for: category)
        guard authStatus == .authorized else {
            logger.debug("\(category.rawValue) not authorized, skipping")
            return
        }

        // Step 2: Show cached summary immediately (fast perceived startup)
        if let cached = await getCachedSummary(for: category) {
            await MainActor.run { onUpdate(category, cached) }
        }

        // Step 3: Check if any timespan needs refresh
        let needsDaily = await cache.needsRefresh(for: category, timeSpan: .daily)
        let needsWeekly = await cache.needsRefresh(for: category, timeSpan: .weekly)
        let needsMonthly = await cache.needsRefresh(for: category, timeSpan: .monthly)

        guard needsDaily || needsWeekly || needsMonthly else {
            logger.debug("\(category.rawValue) cache is fresh, no refresh needed")
            return
        }

        // Step 4: Refresh stale data
        logger.info("\(category.rawValue) has stale data, refreshing...")
        let summary = await refreshCategory(category)
        await MainActor.run { onUpdate(category, summary) }
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
        // Check cache first for fast retrieval (includes persisted metricTrends)
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
    /// Heart is fully implemented; other categories return stub data with TODO markers.
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

        case .sleep:
            // TODO: Implement sleep data fetching in HealthFetcher
            async let current = fetcher.fetchSleepData(for: timeSpan.currentPeriod)
            async let previous = fetcher.fetchSleepData(for: timeSpan.previousPeriod)
            return SleepComparison(previous: try await previous, current: try await current)

        case .performance:
            // TODO: Implement performance data fetching in HealthFetcher
            async let current = fetcher.fetchPerformanceData(for: timeSpan.currentPeriod)
            async let previous = fetcher.fetchPerformanceData(for: timeSpan.previousPeriod)
            return PerformanceComparison(previous: try await previous, current: try await current)

        case .vitality:
            // TODO: Implement vitality data fetching in HealthFetcher
            async let current = fetcher.fetchVitalityData(for: timeSpan.currentPeriod)
            async let previous = fetcher.fetchVitalityData(for: timeSpan.previousPeriod)
            return VitalityComparison(previous: try await previous, current: try await current)

        case .mindfulness:
            // TODO: Implement mindfulness data fetching in HealthFetcher
            async let current = fetcher.fetchMindfulnessData(for: timeSpan.currentPeriod)
            async let previous = fetcher.fetchMindfulnessData(for: timeSpan.previousPeriod)
            return MindfulnessComparison(previous: try await previous, current: try await current)
        }
    }

    /// Refresh category data for home screen tile display.
    /// Uses the LLM-generated shortSummary for the tile instead of just metrics.
    /// Fetches all three timespans (daily, weekly, monthly) and uses monthly for tile.
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

            logger.info("Generated \(category.rawValue) \(timeSpan.rawValue) summary successfully")
            return CategorySummary(
                category: category,
                status: .ready,
                smallSummary: timespanSummary.shortSummary,
                largeSummary: timespanSummary.summaryText,
                lastUpdated: Date()
            )
        } catch HealthServiceError.categoryNotImplemented {
            // Category not yet implemented - return placeholder
            logger.info("\(category.rawValue) category not yet implemented")
            return CategorySummary.noData(for: category)
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
