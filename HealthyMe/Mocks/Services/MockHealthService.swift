//
//  MockHealthService.swift
//  HealthyMe
//
//  Mock implementation of HealthServiceProtocol for demo mode and testing.
//  Returns sample health data without requiring HealthKit access.
//  Designed to demonstrate app functionality during App Store review.
//

import Foundation

/// Mock health service for demo mode and testing.
/// Provides realistic sample data without HealthKit dependency.
actor MockHealthService: HealthServiceProtocol {

    // MARK: - Dependencies

    private let fetcher: MockHealthFetcher

    // MARK: - Cached Summaries

    private var categorySummaries: [HealthCategory: CategorySummary] = [:]

    // MARK: - Initialization

    init(fetcher: MockHealthFetcher = MockHealthFetcher()) {
        self.fetcher = fetcher
    }

    // MARK: - HealthServiceProtocol

    /// Always returns true in demo mode (simulates HealthKit availability)
    nonisolated var isHealthDataAvailable: Bool { true }

    /// Always succeeds immediately in demo mode (no authorization dialog)
    func requestAuthorization(for category: HealthCategory) async throws -> Bool {
        // Brief delay to simulate authorization flow
        try? await Task.sleep(for: .seconds(0.2))
        return true
    }

    /// Always returns authorized in demo mode
    func checkAuthorizationStatus(for category: HealthCategory) async -> HealthAuthorizationStatus {
        return .authorized
    }

    /// Returns cached demo summary or nil if not cached
    func getCachedSummary(for category: HealthCategory) async -> CategorySummary? {
        return categorySummaries[category]
    }

    /// Generates and caches a demo summary for a category
    func refreshCategory(_ category: HealthCategory) async -> CategorySummary {
        let summary = await buildDemoSummary(for: category)
        categorySummaries[category] = summary
        return summary
    }

    /// Refreshes all categories with demo data
    func refreshAllCategories(
        onCategoryUpdate: @escaping @MainActor (HealthCategory, CategorySummary) -> Void
    ) async {
        await withTaskGroup(of: Void.self) { group in
            for category in HealthCategory.allCases {
                group.addTask {
                    let summary = await self.refreshCategory(category)
                    await MainActor.run { onCategoryUpdate(category, summary) }
                }
            }
        }
    }

    /// Returns demo timespan summaries for a category
    func fetchTimespanSummaries(
        for category: HealthCategory,
        onUpdate: @escaping @MainActor (TimeSpan, SummaryLoadingState) -> Void
    ) async {
        // Show loading state briefly for each timespan
        for timeSpan in TimeSpan.allCases {
            await MainActor.run { onUpdate(timeSpan, .loading) }
        }

        // Fetch all timespans concurrently
        await withTaskGroup(of: (TimeSpan, TimespanSummary).self) { group in
            for timeSpan in TimeSpan.allCases {
                group.addTask {
                    let summary = await self.buildTimespanSummary(for: category, timeSpan: timeSpan)
                    return (timeSpan, summary)
                }
            }

            for await (timeSpan, summary) in group {
                await MainActor.run { onUpdate(timeSpan, .loaded(summary)) }
            }
        }
    }

    // MARK: - Demo Summary Builders

    /// Builds a demo CategorySummary with pre-written content
    private func buildDemoSummary(for category: HealthCategory) async -> CategorySummary {
        // Brief delay for realism
        try? await Task.sleep(for: .seconds(0.3))

        let (small, large) = demoSummaryText(for: category)

        return CategorySummary(
            category: category,
            status: .ready,
            smallSummary: small,
            largeSummary: large,
            lastUpdated: Date()
        )
    }

    /// Builds a demo TimespanSummary with pre-written content
    private func buildTimespanSummary(
        for category: HealthCategory,
        timeSpan: TimeSpan
    ) async -> TimespanSummary {
        // Brief delay for realism
        try? await Task.sleep(for: .seconds(0.2))

        // Fetch mock data to build comparison
        let comparison = await fetchComparison(for: category, timeSpan: timeSpan)

        return TimespanSummary(
            timeSpan: timeSpan,
            trend: comparison.trend,
            shortSummary: comparison.fallbackShortSummary,
            summaryText: comparison.fallbackSummary,
            metricsDisplay: comparison.metricsDisplay,
            metricTrends: comparison.metricTrends
        )
    }

    /// Fetches mock comparison data for a category and timespan
    private func fetchComparison(
        for category: HealthCategory,
        timeSpan: TimeSpan
    ) async -> any HealthComparison {
        let currentPeriod = await timeSpan.currentPeriod
        let previousPeriod = await timeSpan.previousPeriod

        switch category {
        case .heart:
            let current = try? await fetcher.fetchHeartData(for: currentPeriod)
            let previous = try? await fetcher.fetchHeartData(for: previousPeriod)
            return HeartComparison(
                previous: previous ?? HeartData.empty(for: previousPeriod),
                current: current ?? HeartData.empty(for: currentPeriod)
            )

        case .sleep:
            let current = try? await fetcher.fetchSleepData(for: currentPeriod)
            let previous = try? await fetcher.fetchSleepData(for: previousPeriod)
            return SleepComparison(
                previous: previous ?? SleepData.empty(for: previousPeriod),
                current: current ?? SleepData.empty(for: currentPeriod)
            )

        case .performance:
            let current = try? await fetcher.fetchPerformanceData(for: currentPeriod)
            let previous = try? await fetcher.fetchPerformanceData(for: previousPeriod)
            return PerformanceComparison(
                previous: previous ?? PerformanceData.empty(for: previousPeriod),
                current: current ?? PerformanceData.empty(for: currentPeriod)
            )

        case .vitality:
            let current = try? await fetcher.fetchVitalityData(for: currentPeriod)
            let previous = try? await fetcher.fetchVitalityData(for: previousPeriod)
            return VitalityComparison(
                previous: previous ?? VitalityData.empty(for: previousPeriod),
                current: current ?? VitalityData.empty(for: currentPeriod)
            )

        case .mindfulness:
            let current = try? await fetcher.fetchMindfulnessData(for: currentPeriod)
            let previous = try? await fetcher.fetchMindfulnessData(for: previousPeriod)
            return MindfulnessComparison(
                previous: previous ?? MindfulnessData.empty(for: previousPeriod),
                current: current ?? MindfulnessData.empty(for: currentPeriod)
            )
        }
    }

    // MARK: - Pre-written Demo Summaries

    /// Returns pre-written (small, large) summary text for each category
    private func demoSummaryText(for category: HealthCategory) -> (String, String) {
        switch category {
        case .heart:
            return (
                "Heart health looking good",
                "Your heart rate metrics are within healthy ranges. Resting heart rate of 58 BPM indicates good cardiovascular fitness, and your HRV shows excellent recovery capacity."
            )

        case .sleep:
            return (
                "Sleep quality is excellent",
                "You're averaging 7.5 hours of sleep with good sleep stage distribution. Your 18% deep sleep is within the ideal range, supporting physical recovery."
            )

        case .performance:
            return (
                "Activity levels on track",
                "Great job staying active! You're exceeding your step goal and maintaining consistent exercise time. Your VO₂ max indicates good cardiovascular fitness."
            )

        case .vitality:
            return (
                "Vitals are stable",
                "Your vital signs are all within normal ranges. Blood oxygen at 98% and respiratory rate of 14/min show healthy baseline function."
            )

        case .mindfulness:
            return (
                "Consistent mindful practice",
                "You're maintaining a regular mindfulness practice with 2 sessions averaging 7.5 minutes each. Consistency is more valuable than duration."
            )
        }
    }
}
