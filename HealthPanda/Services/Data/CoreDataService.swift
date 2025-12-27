//
//  CoreDataService.swift
//  HealthPanda
//
//  Core Data implementation for persisting user state.
//  Only stores data that should persist across app launches.
//  Permission states are checked directly from their respective APIs.
//

import CoreData
import OSLog
import Combine

final class CoreDataService: DataServiceProtocol, ObservableObject {

    // nonisolated(unsafe) allows access from default parameters
    static let shared = CoreDataService()
    static let preview = CoreDataService(inMemory: true)

    private let container: NSPersistentContainer
    private let logger = Logger(subsystem: "com.healthpanda", category: "CoreDataService")

    @Published private(set) var cachedUserState: UserState?

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "HealthPanda")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error {
                Logger(subsystem: "com.healthpanda", category: "CoreDataService")
                    .error("Failed to load store: \(error.localizedDescription)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    func fetchUserState() async throws -> UserState {
        if let cached = cachedUserState {
            return cached
        }

        let request = NSFetchRequest<User>(entityName: "User")
        request.fetchLimit = 1

        if let user = try viewContext.fetch(request).first {
            let state = UserState(
                id: user.id ?? UUID(),
                hasCompletedOnboarding: user.hasCompletedOnboarding
            )
            cachedUserState = state
            return state
        }

        // First launch - create user
        let user = User(context: viewContext)
        user.id = UUID()
        try viewContext.save()

        let state = UserState(id: user.id!)
        cachedUserState = state
        return state
    }

    func updateOnboardingCompleted(_ completed: Bool) async throws {
        try updateUser { $0.hasCompletedOnboarding = completed }
        cachedUserState?.hasCompletedOnboarding = completed
    }

    private func updateUser(_ update: (User) -> Void) throws {
        let request = NSFetchRequest<User>(entityName: "User")
        request.fetchLimit = 1

        guard let user = try viewContext.fetch(request).first else {
            throw CoreDataError.userNotFound
        }

        update(user)
        try viewContext.save()
    }
}

enum CoreDataError: LocalizedError {
    case userNotFound

    var errorDescription: String? {
        "User record not found"
    }
}
