//
//  FoundationModelService.swift
//  HealthPanda
//
//  Apple Foundation Models implementation.
//  Provides generic summary generation for any health category.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

final class FoundationModelService: AiServiceProtocol, SummaryServiceProtocol {

    static let shared = FoundationModelService()

    private let logger: LoggerServiceProtocol = LoggerService.shared

    // MARK: - AiServiceProtocol

    func checkAvailability() async -> AiAvailabilityStatus {
        guard #available(iOS 26, *) else {
            return .unavailableDevice(reason: "Requires iOS 26 or later")
        }
        return await checkFoundationModelsAvailability()
    }

    // MARK: - SummaryServiceProtocol

    /// Generate summary using comparison's prompt and fallback text.
    func generateSummary(
        comparison: any HealthComparison,
        timeSpan: TimeSpan
    ) async throws -> TimespanSummary {
        guard comparison.hasData else {
            return .noData(for: timeSpan)
        }

        guard #available(iOS 26, *) else {
            return generateFallbackSummary(comparison: comparison, timeSpan: timeSpan)
        }

        return try await generateWithLLM(comparison: comparison, timeSpan: timeSpan)
    }

    // MARK: - iOS 26+ Implementation

    @available(iOS 26, *)
    private func checkFoundationModelsAvailability() async -> AiAvailabilityStatus {
        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default

        switch model.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            let reasonString = String(describing: reason)
            if reasonString.lowercased().contains("disabled") {
                return .disabledByUser
            }
            return .unavailableDevice(reason: reasonString)
        @unknown default:
            return .unavailableDevice(reason: "Unknown availability state")
        }
        #else
        return .unavailableDevice(reason: "Apple Intelligence not supported")
        #endif
    }

    @available(iOS 26, *)
    private func generateWithLLM(
        comparison: any HealthComparison,
        timeSpan: TimeSpan
    ) async throws -> TimespanSummary {
        #if canImport(FoundationModels)
        let prompt = "\(timeSpan.comparisonDescription)\n\(comparison.promptText)"

        let session = LanguageModelSession()
        let response = try await session.respond(to: prompt, generating: LLMSummaryResponse.self)

        return TimespanSummary(
            timeSpan: timeSpan,
            trend: comparison.trend,
            shortSummary: response.content.shortSummary,
            summaryText: response.content.detailedSummary,
            metricsDisplay: comparison.metricsDisplay
        )
        #else
        return generateFallbackSummary(comparison: comparison, timeSpan: timeSpan)
        #endif
    }

    // MARK: - Fallback

    private func generateFallbackSummary(
        comparison: any HealthComparison,
        timeSpan: TimeSpan
    ) -> TimespanSummary {
        TimespanSummary(
            timeSpan: timeSpan,
            trend: comparison.trend,
            shortSummary: comparison.fallbackShortSummary,
            summaryText: comparison.fallbackSummary,
            metricsDisplay: comparison.metricsDisplay
        )
    }
}
