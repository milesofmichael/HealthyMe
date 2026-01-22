//
//  AppMode.swift
//  HealthyMe
//
//  Operating modes for the app. Controls whether the app uses real HealthKit
//  data or mock data for demo/testing purposes.
//

import Foundation

/// Operating modes for the app.
/// Extensible for future modes like offline, lite, etc.
enum AppMode: String, CaseIterable, Sendable {
    /// Real HealthKit data - normal operation
    case standard
    /// Sample data for App Store review and testing
    case demo

    // Future possibilities:
    // case offline  // Cached-only mode
    // case lite     // Limited feature set

    /// User-facing display name for this mode
    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .demo: return "Demo"
        }
    }

    /// Description shown in settings UI
    var description: String {
        switch self {
        case .standard: return "Using real health data"
        case .demo: return "Using sample data"
        }
    }
}
