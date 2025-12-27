//
//  OnboardingService.swift
//  HealthPanda
//
//  Coordinates the onboarding flow: device compatibility, permissions, and state persistence.
//
//  Permission states are always checked directly from their respective APIs
//  (HealthKit, FoundationModels) to ensure accurate, real-time status.
//  Only the onboarding completion flag is persisted to Core Data.
//

import SwiftUI
import OSLog

enum DeviceCompatibilityStatus: Equatable {
    case compatible
    case incompatible(reason: String)
}

@Observable
final class OnboardingService {

    private(set) var deviceCompatibility: DeviceCompatibilityStatus = .compatible
    private(set) var aiStatus: AiAvailabilityStatus = .disabledByUser
    private(set) var healthStatus: HealthAuthorizationStatus = .notDetermined
    private(set) var hasCompletedOnboarding = false
    private(set) var isLoading = true
    private(set) var errorMessage: String?

    private let healthService: HealthServiceProtocol
    private let aiService: AiServiceProtocol
    private let dataService: DataServiceProtocol
    private let logger = Logger(subsystem: "com.healthpanda", category: "OnboardingService")

    init(
        healthService: HealthServiceProtocol = HealthService.shared,
        aiService: AiServiceProtocol = FoundationModelService.shared,
        dataService: DataServiceProtocol = CoreDataService.shared
    ) {
        self.healthService = healthService
        self.aiService = aiService
        self.dataService = dataService
    }

    // MARK: - Public API

    func loadInitialState() async {
        isLoading = true
        defer { isLoading = false }

        await checkDeviceCompatibility()

        guard case .compatible = deviceCompatibility else { return }

        do {
            let userState = try await dataService.fetchUserState()
            hasCompletedOnboarding = userState.hasCompletedOnboarding
        } catch {
            logger.error("Failed to load user state: \(error.localizedDescription)")
            errorMessage = "Failed to load your data. Please restart the app."
        }

        await refreshPermissionStates()
    }

    /// Refreshes permission states by querying APIs directly.
    /// This ensures we always have accurate, real-time status.
    func refreshPermissionStates() async {
        aiStatus = await aiService.checkAvailability()
        healthStatus = await healthService.checkAuthorizationStatus()
    }

    func requestHealthAuthorization() async -> Bool {
        do {
            _ = try await healthService.requestAuthorization()
            // Re-check status from the API to get actual state
            healthStatus = await healthService.checkAuthorizationStatus()

            logger.info("Health authorization requested, status: \(String(describing: self.healthStatus))")
            return healthStatus == .authorized
        } catch {
            logger.error("HealthKit auth error: \(error.localizedDescription)")
            errorMessage = "Failed to request health access."
            return false
        }
    }

    func openAppleIntelligenceSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    func confirmAppleIntelligenceEnabled() async {
        // Re-check status from the API
        aiStatus = await aiService.checkAvailability()
        logger.info("Apple Intelligence status: \(String(describing: self.aiStatus))")
    }

    func completeOnboarding() async {
        do {
            try await dataService.updateOnboardingCompleted(true)
            hasCompletedOnboarding = true
            logger.info("Onboarding completed successfully")
        } catch {
            logger.error("Failed to complete onboarding: \(error.localizedDescription)")
            errorMessage = "Failed to save progress."
        }
    }

    // MARK: - Computed Properties

    var isHealthAuthorized: Bool { healthStatus == .authorized }
    var isAiEnabled: Bool { aiStatus == .available }
    var canCompleteOnboarding: Bool { isHealthAuthorized && isAiEnabled }

    var statusMessage: String {
        if !isHealthAuthorized && !isAiEnabled {
            return "Let's get you set up! We need access to your health data and Apple Intelligence."
        } else if !isHealthAuthorized {
            return "Almost there! Just need access to your health data."
        } else if !isAiEnabled {
            return "One more step! Please enable Apple Intelligence."
        }
        return "You're all set! Tap below to start your health journey."
    }

    // MARK: - Private

    private func checkDeviceCompatibility() async {
        guard healthService.isHealthDataAvailable else {
            deviceCompatibility = .incompatible(reason: "This device doesn't support health data")
            return
        }

        let status = await aiService.checkAvailability()
        if case .unavailableDevice(let reason) = status {
            deviceCompatibility = .incompatible(reason: reason)
        }
    }
}
