//
//  SummaryServiceProtocol.swift
//  HealthPanda
//
//  Protocol for generating health summaries using AI.
//

import Foundation

/// Result of summary generation.
struct HealthSummary: Sendable {
    /// Short summary for tile display (~50 chars)
    let small: String
    /// Detailed summary for detail view
    let large: String
}

/// Protocol for AI-powered health summary generation.
protocol SummaryServiceProtocol: Sendable {
    /// Generate summaries comparing heart data between two periods.
    func generateHeartSummary(comparison: HeartComparison) async throws -> HealthSummary
}
