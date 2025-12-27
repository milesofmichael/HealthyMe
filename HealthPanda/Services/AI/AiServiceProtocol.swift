//
//  AiServiceProtocol.swift
//  HealthPanda
//
//  Protocol for AI/LLM services. Designed for extensibility with
//  Foundation Models, Claude API, OpenAI, etc.
//

import Foundation

enum AiAvailabilityStatus: Equatable {
    case available
    case unavailableDevice(reason: String)
    case disabledByUser

    var canBeEnabled: Bool {
        switch self {
        case .available, .disabledByUser: return true
        case .unavailableDevice: return false
        }
    }
}

protocol AiServiceProtocol {
    func checkAvailability() async -> AiAvailabilityStatus
}
