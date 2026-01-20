//
//  HealthCacheProtocol.swift
//  HealthyMe
//
//  Protocol for caching health summaries by category and timespan.
//  Implements staleness rules: daily=24h, weekly=72h, monthly=168h (1 week).
//

import Foundation

/// Protocol for persisting health summaries.
protocol HealthCacheProtocol: Sendable {
    /// Get a cached category summary (for home screen tiles).
    func getSummary(for category: HealthCategory) async -> CategorySummary?

    /// Save a category summary to the cache.
    func saveSummary(_ summary: CategorySummary) async

    /// Get a cached timespan summary for DISPLAY purposes.
    /// Returns cached data if it exists, regardless of staleness.
    /// Use `needsRefresh()` separately to check if background update is needed.
    func getTimespanSummary(
        for category: HealthCategory,
        timeSpan: TimeSpan
    ) async -> TimespanSummary?

    /// Check if a timespan summary needs refreshing (is stale or missing).
    /// Staleness rules:
    /// - Daily: stale after 24 hours
    /// - Weekly: stale after 72 hours (3 days)
    /// - Monthly: stale after 168 hours (1 week)
    func needsRefresh(for category: HealthCategory, timeSpan: TimeSpan) async -> Bool

    /// Save a timespan summary to the cache.
    func saveTimespanSummary(
        _ summary: TimespanSummary,
        for category: HealthCategory
    ) async
}
