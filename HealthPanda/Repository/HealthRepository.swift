//
//  HealthRepository.swift
//  HealthPanda
//
//  Coordinates health data fetching, LLM summarization, and caching.
//

import Foundation
import OSLog

/// Central coordinator for health data operations.
/// Uses actor isolation to prevent data races during concurrent access.
actor HealthRepository {

    static let shared = HealthRepository()

    private let fetcher: HealthFetcherProtocol
    private let summarizer: SummaryServiceProtocol
    private let cache: HealthCacheProtocol
    private let logger = Logger(subsystem: "com.healthpanda", category: "HealthRepository")

    // In-memory cache for current session
    private var summaries: [HealthCategory: CategorySummary] = [:]

    init(
        fetcher: HealthFetcherProtocol = HealthFetcher.shared,
        summarizer: SummaryServiceProtocol = FoundationModelService.shared,
        cache: HealthCacheProtocol = HealthCache.shared
    ) {
        self.fetcher = fetcher
        self.summarizer = summarizer
        self.cache = cache
    }

    // MARK: - Public API

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

    /// Get all cached summaries.
    func getAllCachedSummaries() async -> [HealthCategory: CategorySummary] {
        for category in HealthCategory.allCases {
            if summaries[category] == nil {
                if let cached = await cache.getSummary(for: category) {
                    summaries[category] = cached
                }
            }
        }
        return summaries
    }

    /// Refresh heart category data and generate new summary.
    func refreshHeart() async -> CategorySummary {
        logger.info("Refreshing heart data")

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

    // MARK: - Private

    private func saveSummary(_ summary: CategorySummary) async {
        summaries[summary.category] = summary
        await cache.saveSummary(summary)
    }
}
