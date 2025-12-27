//
//  HealthPandaApp.swift
//  HealthPanda
//
//  App entry point. Shows onboarding for new users, then main content.
//

import SwiftUI

@main
struct HealthPandaApp: App {
    @State private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appViewModel)
                .environment(\.managedObjectContext, CoreDataService.shared.viewContext)
        }
    }
}

// MARK: - App View Model

@Observable
final class AppViewModel {
    private(set) var hasCompletedOnboarding = false
    private(set) var isLoading = true

    private let dataService: DataServiceProtocol

    init(dataService: DataServiceProtocol = CoreDataService.shared) {
        self.dataService = dataService
    }

    func loadInitialState() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let userState = try await dataService.fetchUserState()
            hasCompletedOnboarding = userState.hasCompletedOnboarding
        } catch {
            hasCompletedOnboarding = false
        }
    }
}

// MARK: - Root View

struct RootView: View {
    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
        Group {
            if appViewModel.isLoading {
                ProgressView()
            } else if appViewModel.hasCompletedOnboarding {
                HomeView()
            } else {
                OnboardingView()
                    .onDisappear {
                        Task { await appViewModel.loadInitialState() }
                    }
            }
        }
        .task {
            await appViewModel.loadInitialState()
        }
    }
}

// MARK: - Home View Placeholder

struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Panda mascot placeholder
                ZStack {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 120, height: 120)

                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.pink)
                }

                Text("Welcome to Health Panda!")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Your health categories will appear here")
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.top, 60)
            .navigationTitle("Health Panda")
        }
    }
}

#Preview("Home View") {
    HomeView()
}
