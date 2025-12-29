//
//  HealthCategory.swift
//  HealthPanda
//
//  Health data categories for organizing HealthKit data types.
//

import SwiftUI

enum HealthCategory: String, CaseIterable {
    case heart = "Heart"
    case sleep = "Sleep"
    case mindfulness = "Mindfulness"
    case body = "Body"
    case activity = "Activity"
    case nutrition = "Nutrition"
    case vitals = "Vitals"

    var icon: String {
        switch self {
        case .heart: return "heart.fill"
        case .sleep: return "moon.fill"
        case .mindfulness: return "brain.head.profile"
        case .body: return "figure.stand"
        case .activity: return "figure.run"
        case .nutrition: return "carrot.fill"
        case .vitals: return "waveform.path.ecg"
        }
    }

    var color: Color {
        switch self {
        case .heart: return .pink
        case .sleep: return .indigo
        case .mindfulness: return .cyan
        case .body: return .orange
        case .activity: return .green
        case .nutrition: return .mint
        case .vitals: return .red
        }
    }

    var subtitle: String {
        switch self {
        case .heart: return "Heart rate, blood pressure, HRV"
        case .sleep: return "Sleep duration and quality"
        case .mindfulness: return "Mindful minutes, sessions"
        case .body: return "Weight, BMI, body fat"
        case .activity: return "Steps, workouts, calories"
        case .nutrition: return "Calories, macros, water"
        case .vitals: return "Temperature, respiratory rate"
        }
    }
}
