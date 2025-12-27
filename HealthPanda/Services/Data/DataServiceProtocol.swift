//
//  DataServiceProtocol.swift
//  HealthPanda
//
//  Protocol for data persistence operations.
//
//  Note: Permission states (health access, AI enabled) are NOT stored here.
//  Those are checked directly from their respective APIs (HealthKit, FoundationModels)
//  to ensure we always have accurate, real-time status.
//

import Foundation

/// User's app state for persistence.
/// Only stores data that should persist across app launches.
/// Permission states are queried directly from APIs.
struct UserState {
    let id: UUID
    var hasCompletedOnboarding: Bool

    init(id: UUID = UUID(), hasCompletedOnboarding: Bool = false) {
        self.id = id
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }
}

/// Protocol for data persistence operations.
/// Designed for dependency injection and testability.
protocol DataServiceProtocol {
    /// Fetches the current user state from persistent storage.
    func fetchUserState() async throws -> UserState

    /// Updates the onboarding completion flag.
    func updateOnboardingCompleted(_ completed: Bool) async throws
}
