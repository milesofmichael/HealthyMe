//
//  HealthCategory.swift
//  HealthyMe
//
//  Health data categories and the protocol for category comparisons.
//

import SwiftUI

// MARK: - Metric Trend

/// Trend indicator for an individual health metric.
/// Used to show per-metric status in the UI rather than a single aggregate trend.
/// Generic enough to be used across all health categories (Heart, Sleep, etc.).
/// Codable for persistence in Core Data cache.
struct MetricTrend: Sendable, Codable {
    let name: String
    let value: String
    let direction: TrendDirection

    /// Color for the trend indicator based on direction.
    var color: Color { direction.color }

    /// SF Symbol icon for the trend arrow.
    var icon: String { direction.icon }
}

// MARK: - Health Comparison Protocol

/// Protocol for health data comparisons across any category.
/// Each category's comparison type (HeartComparison, SleepComparison, etc.)
/// conforms to this and provides all text generation.
protocol HealthComparison: Sendable {
    var hasData: Bool { get }
    var promptText: String { get }
    var metricsDisplay: String { get }
    var trend: TrendDirection { get }
    /// Individual trend indicators for each metric in this category.
    /// Displayed in the UI next to each data point.
    var metricTrends: [MetricTrend] { get }
    /// Brief trend summary (~50 chars) when LLM is unavailable
    var fallbackShortSummary: String { get }
    /// Detailed summary (1-2 sentences) when LLM is unavailable
    var fallbackSummary: String { get }
}

// MARK: - Health Category

enum HealthCategory: String, CaseIterable, Codable, Sendable {
    case heart = "Heart"
    case sleep = "Sleep"
    case mindfulness = "Mindfulness"
    case performance = "Performance"
    case vitality = "Vitality"

    var icon: String {
        switch self {
        case .heart: return "heart.fill"
        case .sleep: return "moon.fill"
        case .mindfulness: return "brain.head.profile"
        case .performance: return "figure.run"
        case .vitality: return "waveform.path.ecg"
        }
    }

    var color: Color {
        switch self {
        case .heart: return .categoryHeart
        case .sleep: return .categorySleep
        case .mindfulness: return .categoryMindfulness
        case .performance: return .categoryPerformance
        case .vitality: return .categoryVitality
        }
    }

    var subtitle: String {
        switch self {
        case .heart: return "Heart rate, HRV, resting HR"
        case .sleep: return "Sleep stages, efficiency"
        case .mindfulness: return "Mindful minutes, sessions"
        case .performance: return "Steps, VO₂ max, activity"
        case .vitality: return "Weight, SpO₂, respiratory"
        }
    }
}
