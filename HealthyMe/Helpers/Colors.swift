//
//  Colors.swift
//  HealthyMe
//
//  Centralized color definitions for the application.
//  All UI colors should be defined here for consistency and maintainability.
//

import SwiftUI

/// Centralized color palette for HealthyMe.
/// Uses standard SwiftUI colors for precise color definitions.
extension Color {

    // MARK: - Health Category Colors

    /// Pink color for Heart category
    static let categoryHeart = Color.pink

    /// Indigo color for Sleep category
    static let categorySleep = Color.indigo

    /// Cyan color for Mindfulness category
    static let categoryMindfulness = Color.cyan

    /// Green color for Performance category
    static let categoryPerformance = Color.green

    /// Red color for Vitality category
    static let categoryVitality = Color.red

    // MARK: - Status & Trend Colors

    /// Green for positive states (improving trends, ready status, success)
    static let statusSuccess = Color.green

    /// Orange for stable/neutral states
    static let statusStable = Color.orange

    /// Yellow for warning states (missing critical data)
    static let statusWarning = Color.yellow

    /// Red for negative states (declining trends, no data, errors)
    static let statusError = Color.red

    /// Gray for disabled states
    static let statusDisabled = Color.gray

    // MARK: - UI State Colors

    /// White for high-contrast text on colored backgrounds
    static let textOnColor = Color.white

    // MARK: - System Colors
    // These colors adapt to light/dark mode automatically

    /// Primary background color (adapts to system)
    static var backgroundPrimary: Color {
        Color(.systemBackground)
    }

    /// Secondary background color for cards and sections (adapts to system)
    static var backgroundSecondary: Color {
        Color(.secondarySystemBackground)
    }

    /// Border color for normal state (adapts to system)
    static var borderNormal: Color {
        Color(.systemGray4)
    }
}
