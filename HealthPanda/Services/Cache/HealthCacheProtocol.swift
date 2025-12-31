//
//  HealthCacheProtocol.swift
//  HealthPanda
//
//  Protocol for caching health summaries by category and timespan.
//

import Foundation

/// Protocol for persisting health summaries.
protocol HealthCacheProtocol: Sendable {
    /// Get a cached category summary (for home screen tiles).
    func getSummary(for category: HealthCategory) async -> CategorySummary?

    /// Save a category summary to the cache.
    func saveSummary(_ summary: CategorySummary) async

    /// Get a cached timespan summary (for detail view cards).
    func getTimespanSummary(
        for category: HealthCategory,
        timeSpan: TimeSpan
    ) async -> TimespanSummary?

    /// Save a timespan summary to the cache.
    func saveTimespanSummary(
        _ summary: TimespanSummary,
        for category: HealthCategory
    ) async
}
