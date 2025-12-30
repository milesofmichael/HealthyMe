//
//  SummaryServiceProtocol.swift
//  HealthPanda
//
//  Protocol for generating health summaries using AI.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels

/// Structured output for heart health summary.
/// Uses @Generable for Foundation Models structured generation.
@Generable(description: "A summary of heart health comparing this month to last month")
struct HeartSummaryResponse {
    @Guide(description: "Brief one-sentence summary for tile display, max 50 characters")
    let smallSummary: String

    @Guide(description: "Detailed 2-3 sentence explanation of heart health trends and what they mean")
    let largeSummary: String

    @Guide(description: "Whether heart health is improving, stable, or declining")
    @Guide(.anyOf(["improving", "stable", "declining"]))
    let trend: String
}
#endif

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
