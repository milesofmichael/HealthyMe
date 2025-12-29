//
//  HealthFetcherProtocol.swift
//  HealthPanda
//
//  Protocol for fetching health data from HealthKit.
//

import Foundation

/// Protocol for fetching health metrics from HealthKit.
protocol HealthFetcherProtocol: Sendable {
    /// Fetch heart data averaged over a date interval.
    func fetchHeartData(for period: DateInterval) async throws -> HeartData
}
