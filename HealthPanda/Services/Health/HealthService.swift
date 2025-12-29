//
//  HealthService.swift
//  HealthPanda
//
//  HealthKit authorization service.
//

import HealthKit
import OSLog

final class HealthService: HealthServiceProtocol {

    static let shared = HealthService()

    private let healthStore = HKHealthStore()
    private let logger = Logger(subsystem: "com.healthpanda", category: "HealthService")

    // MARK: - Health Data Type Definitions

    /// Quantity types organized by health category.
    /// Each array contains the HKQuantityTypeIdentifiers relevant to that category.
    private let quantityTypesByCategory: [HealthCategory: [HKQuantityTypeIdentifier]] = [
        .heart: [
            .heartRate,
            .restingHeartRate,
            .walkingHeartRateAverage,
            .heartRateVariabilitySDNN,
            .heartRateRecoveryOneMinute,
            .bloodPressureSystolic,
            .bloodPressureDiastolic,
            .oxygenSaturation,
            .vo2Max,
            .peripheralPerfusionIndex
        ],
        .sleep: [
            // Sleep uses category types, not quantity types
        ],
        .mindfulness: [
            // Mindfulness uses category types, not quantity types
        ],
        .body: [
            .bodyMass,
            .bodyMassIndex,
            .bodyFatPercentage,
            .leanBodyMass,
            .height,
            .waistCircumference
        ],
        .activity: [
            .stepCount,
            .distanceWalkingRunning,
            .distanceCycling,
            .activeEnergyBurned,
            .basalEnergyBurned,
            .flightsClimbed,
            .appleExerciseTime,
            .appleStandTime,
            .appleMoveTime,
            .distanceSwimming,
            .swimmingStrokeCount,
            .pushCount,
            .distanceWheelchair,
            .distanceDownhillSnowSports
        ],
        .nutrition: [
            .dietaryEnergyConsumed,
            .dietaryProtein,
            .dietaryCarbohydrates,
            .dietaryFatTotal,
            .dietaryFatSaturated,
            .dietaryFiber,
            .dietarySugar,
            .dietarySodium,
            .dietaryCholesterol,
            .dietaryWater,
            .dietaryCaffeine,
            .dietaryCalcium,
            .dietaryIron,
            .dietaryVitaminC,
            .dietaryVitaminD
        ],
        .vitals: [
            .bodyTemperature,
            .basalBodyTemperature,
            .respiratoryRate,
            .bloodGlucose,
            .electrodermalActivity,
            .forcedVitalCapacity,
            .forcedExpiratoryVolume1,
            .peakExpiratoryFlowRate,
            .inhalerUsage
        ]
    ]

    /// Category types organized by health category.
    /// These represent data with discrete values (e.g., sleep stages).
    private let categoryTypesByCategory: [HealthCategory: [HKCategoryTypeIdentifier]] = [
        .heart: [
            .highHeartRateEvent,
            .lowHeartRateEvent,
            .irregularHeartRhythmEvent
        ],
        .sleep: [
            .sleepAnalysis
        ],
        .mindfulness: [
            .mindfulSession
        ],
        .body: [],
        .activity: [
            .appleStandHour
        ],
        .nutrition: [],
        .vitals: []
    ]

    /// All health data types to request read access for.
    /// Uses Sets for O(1) lookup and deduplication.
    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()

        // Add all quantity types from each category
        for (_, identifiers) in quantityTypesByCategory {
            for identifier in identifiers {
                if let type = HKQuantityType.quantityType(forIdentifier: identifier) {
                    types.insert(type)
                }
            }
        }

        // Add all category types from each category
        for (_, identifiers) in categoryTypesByCategory {
            for identifier in identifiers {
                if let type = HKCategoryType.categoryType(forIdentifier: identifier) {
                    types.insert(type)
                }
            }
        }

        logger.debug("Requesting \(types.count) health data types")
        return types
    }

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async throws -> Bool {
        guard isHealthDataAvailable else {
            logger.warning("HealthKit not available")
            return false
        }

        return try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
                if let error {
                    self.logger.error("HealthKit auth failed: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    self.logger.info("HealthKit auth: \(success)")
                    continuation.resume(returning: success)
                }
            }
        }
    }

    /// Checks if authorization has been requested.
    ///
    /// HealthKit doesn't expose whether READ access was granted (for privacy).
    /// Instead, we check if the authorization dialog should be shown.
    /// - `.shouldRequest` → User hasn't been asked yet → return `.notDetermined`
    /// - `.unnecessary` → User has been asked before → return `.authorized` (from onboarding perspective)
    /// - `.unknown` → Can't determine → return `.notDetermined`
    func checkAuthorizationStatus() async -> HealthAuthorizationStatus {
        guard isHealthDataAvailable else { return .unavailable }

        do {
            let status = try await healthStore.statusForAuthorizationRequest(
                toShare: [],
                read: readTypes
            )

            switch status {
            case .shouldRequest:
                logger.debug("Health authorization should be requested")
                return .notDetermined
            case .unnecessary:
                logger.debug("Health authorization already requested")
                return .authorized
            case .unknown:
                logger.warning("Health authorization status unknown")
                return .notDetermined
            @unknown default:
                return .notDetermined
            }
        } catch {
            logger.error("Failed to check authorization status: \(error.localizedDescription)")
            return .notDetermined
        }
    }
}
