//
//  HomeView.swift
//  HealthPanda
//
//  Main home screen displaying health category tiles.
//  Shows all categories regardless of permission status.
//  Permissions are requested lazily when user opens a category.
//

import SwiftUI

struct HomeView: View {
    // Local UI state
    @State private var isLoading = true
    @State private var aiStatus: AiAvailabilityStatus = .available
    @State private var summaries: [HealthCategory: CategorySummary] = [:]
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
                CategoryDetailView(
                    category: category,
                    summary: summaries[category],
                    healthService: healthService
                )
            }
            .onChange(of: selectedCategory) { oldValue, newValue in
                // When sheet dismisses (newValue becomes nil), refresh summary from cache
                // This syncs home tile with any summaries generated in the detail view
                if newValue == nil, let category = oldValue {
                    Task {
                        if let updated = await healthService.getCachedSummary(for: category) {
                            summaries[category] = updated
                        }
                    }
                }
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

        // Check AI status
        aiStatus = await aiService.checkAvailability()

        // Load cached summaries for all categories
        for category in HealthCategory.allCases {
            if let cached = await healthService.getCachedSummary(for: category) {
                summaries[category] = cached
            }
        }
    }

    private func refresh() async {
        aiStatus = await aiService.checkAvailability()

        // Only refresh categories that have been previously authorized
        for category in HealthCategory.allCases {
            let status = await healthService.checkAuthorizationStatus(for: category)
            if status == .authorized {
                let summary = await healthService.refreshCategory(category)
                summaries[category] = summary
            }
        }
    }

    // MARK: - Content

    private var contentView: some View {
        VStack(spacing: 12) {
            // System status tiles (errors that need attention)
            systemStatusTiles

            // All health category tiles
            ForEach(HealthCategory.allCases) { category in
                categoryTile(for: category)
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

        // HealthKit unavailable (device doesn't support it)
        if !healthService.isHealthDataAvailable {
            ErrorTile(
                icon: "heart.slash",
                title: "Health Data Unavailable",
                subtitle: "This device doesn't support HealthKit"
            )
        }
    }

    // MARK: - Category Tiles

    @ViewBuilder
    private func categoryTile(for category: HealthCategory) -> some View {
        if let summary = summaries[category] {
            // We have a summary - show appropriate tile based on status
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
            // No summary yet - show as needing sync (error state)
            // This will prompt for permissions when tapped
            ErrorTile(
                icon: category.icon,
                title: category.rawValue,
                subtitle: "Tap to sync"
            ) {
                selectedCategory = category
            }
        }
    }

    // MARK: - Actions

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
