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
    /// Authorization has never been requested
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

    /// Request authorization for health data access.
    /// Returns true if the request was presented to the user.
    func requestAuthorization() async throws -> Bool

    /// Check if health authorization has been requested.
    /// This queries HealthKit directly, not stored state.
    func checkAuthorizationStatus() async -> HealthAuthorizationStatus
}
