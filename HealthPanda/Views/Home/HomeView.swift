//
//  HomeView.swift
//  HealthPanda
//
//  Main home screen displaying health category tiles.
//  Shows all categories regardless of permission status.
//  Permissions are requested lazily when user opens a category.
//
//  Entry Points:
//  - App launch (.task) and pull-to-refresh (.refreshable) both call refresh()
//  - This unified approach shows cached data immediately, then updates stale data
//

import SwiftUI

struct HomeView: View {
    // Local UI state
    @State private var isLoading = true
    @State private var isRefreshing = false
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
            // App launch: use unified refresh flow
            await refresh()
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

    /// Unified refresh function for both app launch and pull-to-refresh.
    /// Flow:
    /// 1. Guard against concurrent refreshes
    /// 2. Check AI availability
    /// 3. Call monolith refresh which:
    ///    - Shows cached data immediately (fast perceived startup)
    ///    - Dispatches background tasks for stale data
    ///    - Updates UI progressively as each category completes
    private func refresh() async {
        // Guard against concurrent refreshes to prevent race conditions
        guard !isRefreshing else { return }
        isRefreshing = true

        // Show loading only on initial load (when no summaries exist yet)
        let isInitialLoad = summaries.isEmpty
        if isInitialLoad {
            isLoading = true
        }

        // Check AI status
        aiStatus = await aiService.checkAvailability()

        // Use the unified monolith refresh from HealthService
        // This shows cached data immediately, then refreshes stale data in background
        await healthService.refreshAllCategories { category, summary in
            // This callback is invoked on MainActor as each category completes
            summaries[category] = summary
        }

        isLoading = false
        isRefreshing = false
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
