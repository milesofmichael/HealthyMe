//
//  SessionProtocol.swift
//  HealthyMe
//
//  Protocol for app session management.
//  Controls operating mode and vends appropriate service implementations.
//

import Foundation

/// Central protocol for app session management.
/// Controls operating mode and vends appropriate service implementations.
/// Conforming types must be Observable to enable SwiftUI binding.
protocol SessionProtocol: AnyObject, Observable {
    /// Current operating mode of the app
    var currentMode: AppMode { get set }

    /// Health service appropriate for current mode
    var healthService: HealthServiceProtocol { get }

    /// AI service appropriate for current mode
    var aiService: AiServiceProtocol { get }
}
