//
//  HealthCache.swift
//  HealthPanda
//
//  Core Data cache for health summaries.
//

import CoreData
import OSLog

final class HealthCache: HealthCacheProtocol, @unchecked Sendable {

    static let shared = HealthCache()

    private let container: NSPersistentContainer
    private let logger = Logger(subsystem: "com.healthpanda", category: "HealthCache")

    init(container: NSPersistentContainer? = nil) {
        self.container = container ?? CoreDataService.shared.container
    }

    func getSummary(for category: HealthCategory) async -> CategorySummary? {
        let context = container.viewContext

        let request = NSFetchRequest<CachedSummary>(entityName: "CachedSummary")
        request.predicate = NSPredicate(format: "category == %@", category.rawValue)
        request.fetchLimit = 1

        do {
            guard let cached = try context.fetch(request).first else {
                return nil
            }
            return mapToSummary(cached)
        } catch {
            logger.error("Failed to fetch cached summary: \(error.localizedDescription)")
            return nil
        }
    }

    func saveSummary(_ summary: CategorySummary) async {
        let context = container.viewContext

        // Find existing or create new
        let request = NSFetchRequest<CachedSummary>(entityName: "CachedSummary")
        request.predicate = NSPredicate(format: "category == %@", summary.category.rawValue)
        request.fetchLimit = 1

        do {
            let cached = try context.fetch(request).first ?? CachedSummary(context: context)
            cached.category = summary.category.rawValue
            cached.status = statusToString(summary.status)
            cached.smallSummary = summary.smallSummary
            cached.largeSummary = summary.largeSummary
            cached.lastUpdated = summary.lastUpdated

            try context.save()
            logger.debug("Saved summary for \(summary.category.rawValue)")
        } catch {
            logger.error("Failed to save summary: \(error.localizedDescription)")
        }
    }

    // MARK: - Private

    private func mapToSummary(_ cached: CachedSummary) -> CategorySummary? {
        guard let categoryString = cached.category,
              let category = HealthCategory(rawValue: categoryString),
              let statusString = cached.status,
              let smallSummary = cached.smallSummary,
              let largeSummary = cached.largeSummary,
              let lastUpdated = cached.lastUpdated else {
            return nil
        }

        return CategorySummary(
            category: category,
            status: stringToStatus(statusString),
            smallSummary: smallSummary,
            largeSummary: largeSummary,
            lastUpdated: lastUpdated
        )
    }

    private func statusToString(_ status: CategoryStatus) -> String {
        switch status {
        case .noData: return "noData"
        case .missingCritical: return "missingCritical"
        case .ready: return "ready"
        }
    }

    private func stringToStatus(_ string: String) -> CategoryStatus {
        switch string {
        case "noData": return .noData
        case "missingCritical": return .missingCritical
        case "ready": return .ready
        default: return .noData
        }
    }
}
