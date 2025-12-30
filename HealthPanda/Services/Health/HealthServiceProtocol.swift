//
//  HealthServiceProtocol.swift
//  HealthPanda
//
//  Protocol for HealthKit operations.
//

import Foundation

/// Authorization status for HealthKit access.
/// Note: HealthKit doesn't expose READ authorization status for privacy.
/// We track whether authorization has been requested, not whether it was granted.
enum HealthAuthorizationStatus {
    /// Authorization has never been requested for this category
    case notDetermined
    /// Authorization has been requested (dialog was shown)
    case authorized
    /// HealthKit is not available on this device
    case unavailable
}

/// Protocol for HealthKit operations.
/// Designed for dependency injection and testability.
protocol HealthServiceProtocol {
    /// Whether HealthKit is available on this device
    var isHealthDataAvailable: Bool { get }

    /// Request authorization for a specific health category.
    /// This is called lazily when the user opens a category tile.
    /// Returns true if the request was presented to the user.
    func requestAuthorization(for category: HealthCategory) async throws -> Bool

    /// Check if health authorization has been requested for a category.
    /// This queries HealthKit directly, not stored state.
    func checkAuthorizationStatus(for category: HealthCategory) async -> HealthAuthorizationStatus

    /// Get cached summary for a category, or nil if not cached.
    func getCachedSummary(for category: HealthCategory) async -> CategorySummary?

    /// Refresh data for a specific category and generate new summary.
    func refreshCategory(_ category: HealthCategory) async -> CategorySummary
}
