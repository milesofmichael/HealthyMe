//
//  HomeView.swift
//  HealthPanda
//
//  Main home screen displaying health category tiles.
//

import SwiftUI

// MARK: - Home View Model

@Observable
final class HomeViewModel {
    private(set) var aiStatus: AiAvailabilityStatus = .available
    private(set) var healthStatus: HealthAuthorizationStatus = .notDetermined
    private(set) var isLoading = true

    // Track which categories have data (for warning tiles)
    private(set) var categoriesWithData: Set<HealthCategory> = []

    private let aiService: AiServiceProtocol
    private let healthService: HealthServiceProtocol

    init(
        aiService: AiServiceProtocol = FoundationModelService.shared,
        healthService: HealthServiceProtocol = HealthService.shared
    ) {
        self.aiService = aiService
        self.healthService = healthService
    }

    func loadStatus() async {
        isLoading = true
        defer { isLoading = false }

        async let ai = aiService.checkAvailability()
        async let health = healthService.checkAuthorizationStatus()

        aiStatus = await ai
        healthStatus = await health

        // For now, simulate that we have data for some categories
        // In production, this would query HealthKit for each category
        if healthStatus == .authorized {
            categoriesWithData = [.heart, .activity, .body]
        }
    }

    func requestHealthPermissions() async {
        _ = try? await healthService.requestAuthorization()
        healthStatus = await healthService.checkAuthorizationStatus()
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    func hasData(for category: HealthCategory) -> Bool {
        categoriesWithData.contains(category)
    }
}

// MARK: - Home View

struct HomeView: View {
    @State private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if viewModel.isLoading {
                        loadingView
                    } else {
                        tileGrid
                    }
                }
                .padding()
            }
            .navigationTitle("Health Panda")
            .refreshable {
                await viewModel.loadStatus()
            }
        }
        .task {
            await viewModel.loadStatus()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading health data...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - Tile Grid

    private var tileGrid: some View {
        VStack(spacing: 12) {
            // System status tiles (errors first)
            systemStatusTiles

            // Health category tiles
            if healthStatus == .authorized {
                categoryTiles
            }
        }
    }

    // MARK: - System Status Tiles

    @ViewBuilder
    private var systemStatusTiles: some View {
        // AI unavailable - device doesn't support Apple Intelligence
        if case .unavailableDevice(let reason) = viewModel.aiStatus {
            ErrorTile(
                icon: "cpu",
                title: "Unsupported Device",
                subtitle: reason
            )
        }

        // AI disabled by user - needs to enable Apple Intelligence
        if viewModel.aiStatus == .disabledByUser {
            ErrorTile(
                icon: "brain",
                title: "Apple Intelligence Required",
                subtitle: "Enable in Settings to continue"
            ) {
                viewModel.openSettings()
            }
        }

        // Health unavailable
        if healthStatus == .unavailable {
            ErrorTile(
                icon: "heart.slash",
                title: "Health Data Unavailable",
                subtitle: "This device doesn't support HealthKit"
            )
        }

        // Health not authorized
        if healthStatus == .notDetermined {
            ErrorTile(
                icon: "heart.text.clipboard",
                title: "Health Permissions Needed",
                subtitle: "Tap to grant access to your health data"
            ) {
                Task { await viewModel.requestHealthPermissions() }
            }
        }
    }

    // MARK: - Category Tiles

    private var categoryTiles: some View {
        ForEach(HealthCategory.allCases, id: \.self) { category in
            categoryTile(for: category)
        }
    }

    @ViewBuilder
    private func categoryTile(for category: HealthCategory) -> some View {
        if viewModel.hasData(for: category) {
            Tile(
                icon: category.icon,
                iconColor: category.color,
                title: category.rawValue,
                subtitle: category.subtitle
            ) {
                // Navigate to category detail
            }
        } else {
            WarningTile(
                icon: category.icon,
                title: category.rawValue,
                subtitle: "No data available"
            ) {
                // Navigate to help/sync instructions
            }
        }
    }

    private var healthStatus: HealthAuthorizationStatus {
        viewModel.healthStatus
    }
}

// MARK: - Previews

#Preview("Home - Loading") {
    HomeView()
}

#Preview("Tiles") {
    ScrollView {
        VStack(spacing: 12) {
            ErrorTile(
                icon: "cpu",
                title: "Unsupported Device",
                subtitle: "This device doesn't support Apple Intelligence"
            )

            ErrorTile(
                icon: "heart.slash",
                title: "Health Permissions Needed",
                subtitle: "Tap to grant access"
            )

            WarningTile(
                icon: "moon.fill",
                title: "Sleep",
                subtitle: "No data available"
            )

            Tile(
                icon: "heart.fill",
                iconColor: .pink,
                title: "Heart",
                subtitle: "Heart rate, blood pressure, HRV"
            )

            Tile(
                icon: "figure.run",
                iconColor: .green,
                title: "Activity",
                subtitle: "Steps, workouts, calories"
            )
        }
        .padding()
    }
}
