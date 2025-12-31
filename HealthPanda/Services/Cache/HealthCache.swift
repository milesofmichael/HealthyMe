//
//  HealthCache.swift
//  HealthPanda
//
//  Core Data cache for health summaries.
//  Supports both category summaries (home tiles) and timespan summaries (detail cards).
//

import CoreData

final class HealthCache: HealthCacheProtocol {

    static let shared = HealthCache()

    private let container: NSPersistentContainer
    private let logger: LoggerServiceProtocol = LoggerService.shared

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
            guard let cached = try context.fetch(request).first else { return nil }
            return mapToTimespanSummary(cached, timeSpan: timeSpan)
        } catch {
            logger.error("Failed to fetch timespan summary: \(error.localizedDescription)")
            return nil
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

    private func mapToTimespanSummary(_ cached: CachedSummary, timeSpan: TimeSpan) -> TimespanSummary? {
        guard let shortSummary = cached.smallSummary,
              let summaryText = cached.largeSummary,
              let trendString = cached.trend,
              let lastUpdated = cached.lastUpdated else {
            return nil
        }

        // Check if stale (older than 1 hour for timespan summaries)
        if Date().timeIntervalSince(lastUpdated) > 3600 {
            return nil
        }

        return TimespanSummary(
            timeSpan: timeSpan,
            trend: TrendDirection(rawValue: trendString) ?? .stable,
            shortSummary: shortSummary,
            summaryText: summaryText,
            metricsDisplay: cached.metricsDisplay ?? ""
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
