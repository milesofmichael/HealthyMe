//
//  HealthCacheProtocol.swift
//  HealthPanda
//
//  Protocol for caching health summaries.
//

import Foundation

/// Protocol for persisting health summaries.
protocol HealthCacheProtocol: Sendable {
    /// Get a cached summary for a category.
    func getSummary(for category: HealthCategory) async -> CategorySummary?

    /// Save a summary to the cache.
    func saveSummary(_ summary: CategorySummary) async
}
