//
//  CategorySummary.swift
//  HealthPanda
//
//  Cached LLM summary for a health category.
//

import Foundation

/// Status of data availability for a category.
enum CategoryStatus: Codable, Sendable {
    /// No data available at all
    case noData
    /// Missing critical data (e.g., no heart rate for heart category)
    case missingCritical
    /// All data available
    case ready
}

/// LLM-generated summary for a health category.
struct CategorySummary: Codable, Sendable {
    let category: HealthCategory
    let status: CategoryStatus

    /// Short summary for tile display (~50 chars)
    let smallSummary: String

    /// Detailed summary for detail view (~500 chars)
    let largeSummary: String

    /// When this summary was generated
    let lastUpdated: Date

    /// Check if summary is stale (older than 24 hours)
    var isStale: Bool {
        Date().timeIntervalSince(lastUpdated) > 86400 // 24 hours
    }

    /// Placeholder when no data is available
    static func noData(for category: HealthCategory) -> CategorySummary {
        CategorySummary(
            category: category,
            status: .noData,
            smallSummary: "No data available",
            largeSummary: "We don't have any \(category.rawValue.lowercased()) data yet. Please sync your health data or grant permissions in Settings.",
            lastUpdated: Date()
        )
    }

    /// Placeholder when missing critical data
    static func missingCritical(for category: HealthCategory) -> CategorySummary {
        CategorySummary(
            category: category,
            status: .missingCritical,
            smallSummary: "Missing key metrics",
            largeSummary: "We're missing some important \(category.rawValue.lowercased()) metrics. Please check your Health app to ensure data is being recorded.",
            lastUpdated: Date()
        )
    }
}
