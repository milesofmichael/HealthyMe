//
//  HealthCategory.swift
//  HealthPanda
//
//  Health data categories for organizing HealthKit data types.
//  Limited to 5 focused categories for better user experience.
//

import SwiftUI

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
