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

// MARK: - Medical Source

/// Authoritative medical source for a health category's metrics.
/// Used to provide citations alongside AI-generated insights,
/// ensuring users can verify health information from trusted organizations.
struct MedicalSource: Sendable, Identifiable {
    let title: String
    let organization: String
    let url: URL

    var id: URL { url }
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

    /// Category-specific phrasing for the disclaimer's reference to sources below.
    var sourcesHint: String {
        switch self {
        case .heart: return "a healthy heart"
        case .sleep: return "healthy sleep habits"
        case .mindfulness: return "the benefits of mindfulness meditation"
        case .performance: return "physical activity guidelines"
        case .vitality: return "vital health indicators"
        }
    }

    /// Authoritative medical sources for the metrics in this category.
    /// Displayed as citations alongside AI-generated insights so users
    /// can verify health information from trusted organizations.
    var sources: [MedicalSource] {
        switch self {
        case .heart:
            return [
                MedicalSource(
                    title: "All About Heart Rate",
                    organization: "American Heart Association",
                    url: URL(string: "https://www.heart.org/en/health-topics/high-blood-pressure/the-facts-about-high-blood-pressure/all-about-heart-rate-pulse")!
                ),
                MedicalSource(
                    title: "Heart Rate: What's Normal?",
                    organization: "Mayo Clinic",
                    url: URL(string: "https://www.mayoclinic.org/healthy-lifestyle/fitness/expert-answers/heart-rate/faq-20057979")!
                ),
                MedicalSource(
                    title: "Heart Rate Variability (HRV)",
                    organization: "Cleveland Clinic",
                    url: URL(string: "https://my.clevelandclinic.org/health/symptoms/21773-heart-rate-variability-hrv")!
                ),
            ]
        case .sleep:
            return [
                MedicalSource(
                    title: "Sleep and Sleep Disorders",
                    organization: "CDC",
                    url: URL(string: "https://www.cdc.gov/sleep/")!
                ),
                MedicalSource(
                    title: "Sleep Deprivation and Deficiency",
                    organization: "National Heart, Lung, and Blood Institute",
                    url: URL(string: "https://www.nhlbi.nih.gov/health/sleep-deprivation")!
                ),
                MedicalSource(
                    title: "Stages of Sleep",
                    organization: "Sleep Foundation",
                    url: URL(string: "https://www.sleepfoundation.org/stages-of-sleep")!
                ),
            ]
        case .performance:
            return [
                MedicalSource(
                    title: "Physical Activity",
                    organization: "World Health Organization",
                    url: URL(string: "https://www.who.int/news-room/fact-sheets/detail/physical-activity")!
                ),
                MedicalSource(
                    title: "Physical Activity Recommendations",
                    organization: "American Heart Association",
                    url: URL(string: "https://www.heart.org/en/healthy-living/fitness/fitness-basics/aha-recs-for-physical-activity-in-adults")!
                ),
                MedicalSource(
                    title: "Physical Activity Basics",
                    organization: "CDC",
                    url: URL(string: "https://www.cdc.gov/physicalactivity/")!
                ),
            ]
        case .vitality:
            return [
                MedicalSource(
                    title: "Obesity and Overweight",
                    organization: "World Health Organization",
                    url: URL(string: "https://www.who.int/news-room/fact-sheets/detail/obesity-and-overweight")!
                ),
                MedicalSource(
                    title: "Pulse Oximetry",
                    organization: "Mayo Clinic",
                    url: URL(string: "https://www.mayoclinic.org/tests-procedures/pulse-oximetry/about/pac-20385604")!
                ),
                MedicalSource(
                    title: "Vital Signs",
                    organization: "MedlinePlus (NIH)",
                    url: URL(string: "https://medlineplus.gov/vitalsigns.html")!
                ),
            ]
        case .mindfulness:
            return [
                MedicalSource(
                    title: "Meditation and Mindfulness",
                    organization: "NIH — NCCIH",
                    url: URL(string: "https://www.nccih.nih.gov/health/meditation-and-mindfulness-what-you-need-to-know")!
                ),
                MedicalSource(
                    title: "Mindfulness Meditation",
                    organization: "American Psychological Association",
                    url: URL(string: "https://www.apa.org/topics/mindfulness/meditation")!
                ),
                MedicalSource(
                    title: "Meditation: A Simple, Fast Way to Reduce Stress",
                    organization: "Mayo Clinic",
                    url: URL(string: "https://www.mayoclinic.org/tests-procedures/meditation/in-depth/meditation/art-20045858")!
                ),
            ]
        }
    }
}
