//
//  HealthCache.swift
//  HealthyMe
//
//  Core Data cache for health summaries.
//  Supports both category summaries (home tiles) and timespan summaries (detail cards).
//
//  Cache Freshness Rules:
//  - Daily summaries: stale after 24 hours (86400 seconds)
//  - Weekly summaries: stale after 72 hours / 3 days (259200 seconds)
//  - Monthly summaries: stale after 168 hours / 1 week (604800 seconds)
//

import CoreData

final class HealthCache: HealthCacheProtocol {

    static let shared = HealthCache()

    private let container: NSPersistentContainer
    private let logger: LoggerServiceProtocol = LoggerService.shared

    // MARK: - Staleness Intervals (in seconds)

    /// Returns the maximum age (in seconds) before a cached summary is considered stale.
    /// - Daily: 24 hours - data changes frequently
    /// - Weekly: 3 days - moderate update frequency
    /// - Monthly: 1 week - data is relatively stable
    private func maxAge(for timeSpan: TimeSpan) -> TimeInterval {
        switch timeSpan {
        case .daily:   return 86400    // 24 hours
        case .weekly:  return 259200   // 72 hours (3 days)
        case .monthly: return 604800   // 168 hours (1 week)
        }
    }

    init(container: NSPersistentContainer? = nil) {
        self.container = container ?? CoreDataService.shared.container
    }

    // MARK: - Category Summaries (Home Screen)

    func getSummary(for category: HealthCategory) async -> CategorySummary? {
        let context = container.viewContext

        let request = NSFetchRequest<CachedSummary>(entityName: "CachedSummary")
        request.predicate = NSPredicate(
            format: "category == %@ AND timeSpan == nil",
            category.rawValue
        )
        request.fetchLimit = 1

        do {
            guard let cached = try context.fetch(request).first else { return nil }
            return mapToCategorySummary(cached, category: category)
        } catch {
            logger.error("Failed to fetch cached summary: \(error.localizedDescription)")
            return nil
        }
    }

    func saveSummary(_ summary: CategorySummary) async {
        let context = container.viewContext

        let request = NSFetchRequest<CachedSummary>(entityName: "CachedSummary")
        request.predicate = NSPredicate(
            format: "category == %@ AND timeSpan == nil",
            summary.category.rawValue
        )
        request.fetchLimit = 1

        do {
            let cached = try context.fetch(request).first ?? CachedSummary(context: context)
            cached.category = summary.category.rawValue
            cached.timeSpan = nil
            cached.status = summary.status.rawString
            cached.smallSummary = summary.smallSummary
            cached.largeSummary = summary.largeSummary
            cached.lastUpdated = summary.lastUpdated

            try context.save()
            logger.debug("Saved category summary for \(summary.category.rawValue)")
        } catch {
            logger.error("Failed to save summary: \(error.localizedDescription)")
        }
    }

    // MARK: - Timespan Summaries (Detail View)

    func getTimespanSummary(
        for category: HealthCategory,
        timeSpan: TimeSpan
    ) async -> TimespanSummary? {
        let context = container.viewContext

        let request = NSFetchRequest<CachedSummary>(entityName: "CachedSummary")
        request.predicate = NSPredicate(
            format: "category == %@ AND timeSpan == %@",
            category.rawValue,
            timeSpan.rawValue
        )
        request.fetchLimit = 1

        do {
            guard let cached = try context.fetch(request).first else {
                logger.debug("No cache entry for \(category.rawValue) \(timeSpan.rawValue)")
                return nil
            }
            return mapToTimespanSummary(cached, timeSpan: timeSpan)
        } catch {
            logger.error("Failed to fetch timespan summary: \(error.localizedDescription)")
            return nil
        }
    }

    func needsRefresh(for category: HealthCategory, timeSpan: TimeSpan) async -> Bool {
        let context = container.viewContext

        let request = NSFetchRequest<CachedSummary>(entityName: "CachedSummary")
        request.predicate = NSPredicate(
            format: "category == %@ AND timeSpan == %@",
            category.rawValue,
            timeSpan.rawValue
        )
        request.fetchLimit = 1

        do {
            guard let cached = try context.fetch(request).first,
                  let lastUpdated = cached.lastUpdated else {
                // No cache entry exists - needs refresh
                logger.debug("\(category.rawValue) \(timeSpan.rawValue): no cache, needs refresh")
                return true
            }

            let age = Date().timeIntervalSince(lastUpdated)
            let maxAllowedAge = maxAge(for: timeSpan)
            let isStale = age > maxAllowedAge

            if isStale {
                logger.debug("\(category.rawValue) \(timeSpan.rawValue): stale (age: \(Int(age/3600))h, max: \(Int(maxAllowedAge/3600))h)")
            } else {
                logger.debug("\(category.rawValue) \(timeSpan.rawValue): fresh (age: \(Int(age/3600))h)")
            }

            return isStale
        } catch {
            logger.error("Failed to check cache freshness: \(error.localizedDescription)")
            return true // On error, assume needs refresh
        }
    }

    func saveTimespanSummary(
        _ summary: TimespanSummary,
        for category: HealthCategory
    ) async {
        let context = container.viewContext

        let request = NSFetchRequest<CachedSummary>(entityName: "CachedSummary")
        request.predicate = NSPredicate(
            format: "category == %@ AND timeSpan == %@",
            category.rawValue,
            summary.timeSpan.rawValue
        )
        request.fetchLimit = 1

        do {
            let cached = try context.fetch(request).first ?? CachedSummary(context: context)
            cached.category = category.rawValue
            cached.timeSpan = summary.timeSpan.rawValue
            cached.trend = summary.trend.rawValue
            cached.smallSummary = summary.shortSummary
            cached.largeSummary = summary.summaryText
            cached.metricsDisplay = summary.metricsDisplay
            cached.lastUpdated = Date()
            cached.status = "ready"

            // Encode metricTrends as JSON data for persistence
            if !summary.metricTrends.isEmpty {
                cached.metricTrendsData = try? JSONEncoder().encode(summary.metricTrends)
            }

            try context.save()
            logger.debug("Saved \(summary.timeSpan.rawValue) summary for \(category.rawValue)")
        } catch {
            logger.error("Failed to save timespan summary: \(error.localizedDescription)")
        }
    }

    // MARK: - Mapping

    private func mapToCategorySummary(_ cached: CachedSummary, category: HealthCategory) -> CategorySummary? {
        guard let statusString = cached.status,
              let smallSummary = cached.smallSummary,
              let largeSummary = cached.largeSummary,
              let lastUpdated = cached.lastUpdated else {
            return nil
        }

        return CategorySummary(
            category: category,
            status: CategoryStatus.from(rawString: statusString),
            smallSummary: smallSummary,
            largeSummary: largeSummary,
            lastUpdated: lastUpdated
        )
    }

    /// Maps Core Data entity to TimespanSummary for DISPLAY.
    /// Does NOT check staleness - always returns data if it exists.
    /// Staleness is checked separately via needsRefresh() for background updates.
    private func mapToTimespanSummary(_ cached: CachedSummary, timeSpan: TimeSpan) -> TimespanSummary? {
        guard let shortSummary = cached.smallSummary,
              let summaryText = cached.largeSummary,
              let trendString = cached.trend else {
            return nil
        }

        // Decode metricTrends from JSON data if available
        var metricTrends: [MetricTrend] = []
        if let data = cached.metricTrendsData {
            metricTrends = (try? JSONDecoder().decode([MetricTrend].self, from: data)) ?? []
        }

        return TimespanSummary(
            timeSpan: timeSpan,
            trend: TrendDirection(rawValue: trendString) ?? .stable,
            shortSummary: shortSummary,
            summaryText: summaryText,
            metricsDisplay: cached.metricsDisplay ?? "",
            metricTrends: metricTrends
        )
    }
}

// MARK: - CategoryStatus Extension

extension CategoryStatus {
    /// O(1) - constant time string conversion.
    var rawString: String {
        switch self {
        case .noData: return "noData"
        case .missingCritical: return "missingCritical"
        case .ready: return "ready"
        }
    }

    /// O(1) - switch statement provides constant time lookup.
    static func from(rawString: String) -> CategoryStatus {
        switch rawString {
        case "noData": return .noData
        case "missingCritical": return .missingCritical
        case "ready": return .ready
        default: return .noData
        }
    }
}
