//
//  HomeView.swift
//  HealthPanda
//
//  Main home screen displaying health category tiles.
//

import SwiftUI

struct HomeView: View {
    // Local UI state
    @State private var isLoading = true
    @State private var aiStatus: AiAvailabilityStatus = .available
    @State private var healthStatus: HealthAuthorizationStatus = .notDetermined
    @State private var heartSummary: CategorySummary?
    @State private var selectedCategory: HealthCategory?

    // Services accessed directly
    private let aiService: AiServiceProtocol = FoundationModelService.shared
    private let healthService: HealthServiceProtocol = HealthService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if isLoading {
                        loadingView
                    } else {
                        contentView
                    }
                }
                .padding()
            }
            .navigationTitle("Health Panda")
            .refreshable {
                await refresh()
            }
            .sheet(item: $selectedCategory) { category in
                CategoryDetailView(category: category, summary: heartSummary)
            }
        }
        .task {
            await loadInitialState()
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading health data...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private func loadInitialState() async {
        isLoading = true
        defer { isLoading = false }

        async let ai = aiService.checkAvailability()
        async let health = healthService.checkAuthorizationStatus()

        aiStatus = await ai
        healthStatus = await health

        // Load health data regardless of AI status
        if healthStatus == .authorized {
            heartSummary = await HealthRepository.shared.getCachedSummary(for: .heart)

            if heartSummary == nil || heartSummary?.isStale == true {
                heartSummary = await HealthRepository.shared.refreshHeart()
            }
        }
    }

    private func refresh() async {
        async let ai = aiService.checkAvailability()
        async let health = healthService.checkAuthorizationStatus()

        aiStatus = await ai
        healthStatus = await health

        if healthStatus == .authorized {
            heartSummary = await HealthRepository.shared.refreshHeart()
        }
    }

    // MARK: - Content

    private var contentView: some View {
        VStack(spacing: 12) {
            // System status tiles (errors)
            systemStatusTiles

            // Health category tiles (always show if authorized)
            if healthStatus == .authorized {
                heartTile
            }
        }
    }

    // MARK: - System Status Tiles

    @ViewBuilder
    private var systemStatusTiles: some View {
        // AI unavailable - show error but don't block health data
        if case .unavailableDevice(let reason) = aiStatus {
            ErrorTile(
                icon: "cpu",
                title: "Unsupported Device",
                subtitle: reason
            )
        }

        if aiStatus == .disabledByUser {
            ErrorTile(
                icon: "brain",
                title: "Apple Intelligence Required",
                subtitle: "Enable in Settings for personalized insights"
            ) {
                openSettings()
            }
        }

        // Health errors
        if healthStatus == .unavailable {
            ErrorTile(
                icon: "heart.slash",
                title: "Health Data Unavailable",
                subtitle: "This device doesn't support HealthKit"
            )
        }

        if healthStatus == .notDetermined {
            ErrorTile(
                icon: "heart.text.clipboard",
                title: "Health Permissions Needed",
                subtitle: "Tap to grant access to your health data"
            ) {
                Task { await requestHealthPermissions() }
            }
        }
    }

    // MARK: - Heart Tile

    @ViewBuilder
    private var heartTile: some View {
        let category = HealthCategory.heart

        if let summary = heartSummary {
            switch summary.status {
            case .noData:
                ErrorTile(
                    icon: category.icon,
                    title: category.rawValue,
                    subtitle: summary.smallSummary
                ) {
                    selectedCategory = category
                }

            case .missingCritical:
                WarningTile(
                    icon: category.icon,
                    title: category.rawValue,
                    subtitle: summary.smallSummary
                ) {
                    selectedCategory = category
                }

            case .ready:
                Tile(
                    icon: category.icon,
                    iconColor: category.color,
                    title: category.rawValue,
                    subtitle: summary.smallSummary
                ) {
                    selectedCategory = category
                }
            }
        } else {
            Tile(
                icon: category.icon,
                iconColor: category.color,
                title: category.rawValue,
                subtitle: "Loading..."
            )
        }
    }

    // MARK: - Actions

    private func requestHealthPermissions() async {
        _ = try? await healthService.requestAuthorization()
        healthStatus = await healthService.checkAuthorizationStatus()

        if healthStatus == .authorized {
            heartSummary = await HealthRepository.shared.refreshHeart()
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - HealthCategory Identifiable

extension HealthCategory: Identifiable {
    var id: String { rawValue }
}

// MARK: - Previews

#Preview("Home") {
    HomeView()
}
