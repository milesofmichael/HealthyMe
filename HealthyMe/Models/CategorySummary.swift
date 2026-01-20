//
//  CategorySummary.swift
//  HealthyMe
//
//  Cached LLM summary for a health category.
//

import Foundation
import SwiftUI

/// Status of data availability for a category.
enum CategoryStatus: Codable, Sendable {
    case noData
    case missingCritical
    case ready
}

/// Trend direction for health metrics.
enum TrendDirection: String, Codable, Sendable {
    case improving
    case stable
    case declining

    var icon: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .declining: return "arrow.down.right"
        }
    }

    var color: Color {
        switch self {
        case .improving: return .statusSuccess
        case .stable: return .statusStable
        case .declining: return .statusError
        }
    }
}

/// Loading state for async summary fetching.
enum SummaryLoadingState: Sendable {
    case idle
    case loading
    case loaded(TimespanSummary)
    case failed

    var summary: TimespanSummary? {
        if case .loaded(let s) = self { return s }
        return nil
    }
}

/// LLM-generated summary for a specific timespan.
struct TimespanSummary: Sendable {
    let timeSpan: TimeSpan
    let trend: TrendDirection
    /// Brief trend summary (~50 chars) for home screen tiles
    let shortSummary: String
    /// Detailed 1-2 sentence explanation for detail view
    let summaryText: String
    /// Formatted metrics from the data model (e.g., "68 BPM avg · 55 resting")
    let metricsDisplay: String
    /// Individual trend indicators for each metric.
    /// Used to show per-metric status instead of aggregate trend badge.
    let metricTrends: [MetricTrend]

    static func noData(for timeSpan: TimeSpan) -> TimespanSummary {
        TimespanSummary(
            timeSpan: timeSpan,
            trend: .stable,
            shortSummary: "No data available",
            summaryText: "No data available.",
            metricsDisplay: "",
            metricTrends: []
        )
    }
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
