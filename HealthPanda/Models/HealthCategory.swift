//
//  HealthCategory.swift
//  HealthPanda
//
//  Health data categories and the protocol for category comparisons.
//

import SwiftUI

// MARK: - Health Comparison Protocol

/// Protocol for health data comparisons across any category.
/// Each category's comparison type (HeartComparison, SleepComparison, etc.)
/// conforms to this and provides all text generation.
protocol HealthComparison: Sendable {
    var hasData: Bool { get }
    var promptText: String { get }
    var metricsDisplay: String { get }
    var trend: TrendDirection { get }
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
        case .heart: return .pink
        case .sleep: return .indigo
        case .mindfulness: return .cyan
        case .performance: return .green
        case .vitality: return .red
        }
    }

    var subtitle: String {
        switch self {
        case .heart: return "Heart rate, blood oxygen, HRV"
        case .sleep: return "Sleep duration and quality"
        case .mindfulness: return "Mindful minutes, sessions"
        case .performance: return "Steps, workouts, activity"
        case .vitality: return "Temperature, respiratory rate"
        }
    }
}
