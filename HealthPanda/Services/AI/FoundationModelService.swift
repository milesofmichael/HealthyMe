//
//  FoundationModelService.swift
//  HealthPanda
//
//  Apple Foundation Models implementation. Requires iOS 26+ with Apple Intelligence enabled.
//

import Foundation
import OSLog

#if canImport(FoundationModels)
import FoundationModels
#endif

final class FoundationModelService: AiServiceProtocol {

    static let shared = FoundationModelService()

    private let logger = Logger(subsystem: "com.healthpanda", category: "FoundationModelService")

    func checkAvailability() async -> AiAvailabilityStatus {
        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default

        switch model.availability {
        case .available:
            logger.info("Foundation Models available")
            return .available

        case .unavailable(let reason):
            let reasonString = String(describing: reason)
            logger.warning("Foundation Models unavailable: \(reasonString)")

            // Check if user just needs to enable Apple Intelligence
            if reasonString.lowercased().contains("disabled") ||
               reasonString.lowercased().contains("not enabled") {
                return .disabledByUser
            }
            return .unavailableDevice(reason: reasonString)

        @unknown default:
            logger.error("Unknown availability state")
            return .unavailableDevice(reason: "Unknown availability state")
        }
        #else
        logger.warning("FoundationModels not available")
        return .unavailableDevice(reason: "This device does not support Apple Intelligence")
        #endif
    }
}
