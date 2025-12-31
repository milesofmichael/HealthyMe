//
//  SummaryServiceProtocol.swift
//  HealthPanda
//
//  Protocol for generating health summaries using AI.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels

/// Structured output for LLM summary generation.
/// Reusable across all health categories.
@available(iOS 26, *)
@Generable(description: "A health summary comparing two time periods")
struct LLMSummaryResponse {
    @Guide(description: "Brief one-sentence summary, max 50 characters")
    let shortSummary: String

    @Guide(description: "Detailed 1-2 sentence explanation of health trends")
    let detailedSummary: String
}
#endif

/// Result of summary generation for home screen tiles.
struct HealthSummary: Sendable {
    let small: String
    let large: String
}

/// Protocol for AI-powered health summary generation.
/// Works with any HealthComparison type for reusability across categories.
protocol SummaryServiceProtocol: Sendable {
    /// Generate a summary for any health comparison.
    /// The comparison provides all necessary prompts and fallback text.
    func generateSummary(
        comparison: any HealthComparison,
        timeSpan: TimeSpan
    ) async throws -> TimespanSummary
}
