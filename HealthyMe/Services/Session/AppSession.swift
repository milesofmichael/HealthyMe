//
//  AppSession.swift
//  HealthyMe
//
//  Observable implementation of SessionProtocol.
//  Manages app operating mode and vends appropriate service implementations.
//

import Foundation
import Observation

/// Observable app session that controls operating mode and service selection.
/// Injected into the environment at app launch for global access.
@Observable
final class AppSession: SessionProtocol {

    // MARK: - Stored Properties

    /// Current operating mode (not persisted - resets to standard on app launch)
    var currentMode: AppMode = .standard {
        didSet {
            // Reset cached mock service when mode changes to ensure fresh state
            _mockHealthService = nil
        }
    }

    // MARK: - Services

    /// Cached mock service instance (created on first access in demo mode)
    private var _mockHealthService: MockHealthService?

    // MARK: - Initialization

    init() {
        // Default to standard mode on every app launch
    }

    // MARK: - SessionProtocol

    /// Returns the appropriate health service based on current mode
    var healthService: HealthServiceProtocol {
        switch currentMode {
        case .standard:
            return HealthService.shared
        case .demo:
            if _mockHealthService == nil {
                _mockHealthService = MockHealthService()
            }
            return _mockHealthService!
        }
    }

    /// Returns the appropriate AI service based on current mode
    /// Note: AI service works in both modes (demo uses pre-written summaries but
    /// could still use AI if needed for consistency)
    var aiService: AiServiceProtocol {
        return FoundationModelService.shared
    }

    /// Bool binding for SwiftUI Toggle
    var isDemoMode: Bool {
        get { currentMode == .demo }
        set { currentMode = newValue ? .demo : .standard }
    }
}
