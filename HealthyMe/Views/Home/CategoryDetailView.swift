//
//  CategoryDetailView.swift
//  HealthyMe
//
//  Detail view showing full health summary for a category.
//  Handles lazy permission requests and data fetching.
//
//  First Permission Edge Case:
//  When user opens a category and grants permission for the first time,
//  we only refresh that single category (not the full monolith refresh).
//  This is handled by requestPermissionsAndRefresh() -> refreshData() -> refreshCategory().
//

import SwiftUI

struct CategoryDetailView: View {
    let category: HealthCategory
    let summary: CategorySummary?

    // Session provides appropriate health service based on mode (standard/demo)
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var currentSummary: CategorySummary?
    @State private var isLoading = false
    @State private var authStatus: HealthAuthorizationStatus = .notDetermined

    // Timespan loading states (uses Dictionary for O(1) lookup)
    @State private var timespanStates: [TimeSpan: SummaryLoadingState] = [
        .daily: .idle,
        .weekly: .idle,
        .monthly: .idle
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection

                    if isLoading {
                        loadingSection
                    } else if authStatus == .notDetermined {
                        permissionSection
                    } else {
                        // Show timespan cards for all categories
                        // (Non-heart categories will show "not implemented" until fetchers are added)
                        timespanSummariesSection
                    }

                    disclaimerFooter
                }
                .padding()
            }
            .navigationTitle(category.rawValue)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Data Loading

    /// Load data for this category.
    /// STEP 1: Show cached data IMMEDIATELY (category summary + timespan cards)
    /// STEP 2: Background refresh if stale
    private func loadData() async {
        // Show passed summary immediately
        currentSummary = summary

        // Check auth status
        authStatus = await session.healthService.checkAuthorizationStatus(for: category)
        guard authStatus == .authorized else { return }

        // STEP 1: Load cached timespan data IMMEDIATELY (before any refresh)
        await fetchTimespanSummaries()

        // STEP 2: Background refresh category summary if needed
        if currentSummary == nil {
            currentSummary = await session.healthService.refreshCategory(category)
        }
    }

    /// First-time permission grant - fetch single category only.
    private func requestPermissionsAndRefresh() async {
        isLoading = true
        defer { isLoading = false }

        _ = try? await session.healthService.requestAuthorization(for: category)
        authStatus = await session.healthService.checkAuthorizationStatus(for: category)

        if authStatus == .authorized {
            // First time - no cache, need to fetch everything
            currentSummary = await session.healthService.refreshCategory(category)
            await fetchTimespanSummaries()
        }
    }

    /// Load cached timespan data immediately, refresh stale data in background.
    private func fetchTimespanSummaries() async {
        await session.healthService.fetchTimespanSummaries(for: category) { timeSpan, state in
            timespanStates[timeSpan] = state
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 16) {
            Image(systemName: category.icon)
                .font(.system(size: 40))
                .foregroundStyle(category.color)

            VStack(alignment: .leading, spacing: 4) {
                Text(category.rawValue)
                    .font(.title2)
                    .fontWeight(.bold)

                if let summary = currentSummary {
                    statusBadge(for: summary.status)
                } else if authStatus == .notDetermined {
                    Text("Permissions needed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func statusBadge(for status: CategoryStatus) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor(for: status))
                .frame(width: 8, height: 8)

            Text(statusText(for: status))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func statusColor(for status: CategoryStatus) -> Color {
        switch status {
        case .ready: return .statusSuccess
        case .missingCritical: return .statusWarning
        case .noData: return .statusError
        }
    }

    private func statusText(for status: CategoryStatus) -> String {
        switch status {
        case .ready: return "Up to date"
        case .missingCritical: return "Missing data"
        case .noData: return "No data"
        }
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading \(category.rawValue.lowercased()) data...")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Permission Request

    private var permissionSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Permission Required")
                .font(.headline)

            Text("To show your \(category.rawValue.lowercased()) insights, HealthyMe needs access to your \(category.subtitle.lowercased()) data.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await requestPermissionsAndRefresh()
                }
            } label: {
                Text("Allow Access")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(category.color)
                    .foregroundStyle(Color.textOnColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.headline)

            if let summary = currentSummary {
                Text(summary.largeSummary)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Last updated: \(summary.lastUpdated.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Text("No summary available yet. Pull to refresh.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Timespan Summaries

    /// Section showing daily, weekly, and monthly health summaries.
    private var timespanSummariesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Health Trends")
                .font(.headline)

            ForEach(TimeSpan.allCases, id: \.self) { timeSpan in
                HealthSummaryCard(
                    timeSpan: timeSpan,
                    loadingState: timespanStates[timeSpan] ?? .idle,
                    accentColor: category.color
                )
            }
        }
    }

    // MARK: - Disclaimer

    private var disclaimerFooter: some View {
        Text("HealthyMe provides wellness insights for informational purposes only. This is not medical advice. Always consult a healthcare professional for medical decisions.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
    }
}

// MARK: - Previews

#Preview("Heart - Ready") {
    CategoryDetailView(
        category: .heart,
        summary: CategorySummary(
            category: .heart,
            status: .ready,
            smallSummary: "Heart rate trending up 3%",
            largeSummary: "Your heart rate has increased slightly this month compared to last month, averaging 72 BPM versus 70 BPM. Your resting heart rate remains healthy at 58 BPM. Overall, your cardiovascular metrics indicate good heart health.",
            lastUpdated: Date()
        )
    )
    .environment(AppSession())
}

#Preview("Heart - No Data") {
    CategoryDetailView(
        category: .heart,
        summary: CategorySummary.noData(for: .heart)
    )
    .environment(AppSession())
}

#Preview("Sleep - Fallback Summary") {
    CategoryDetailView(
        category: .sleep,
        summary: CategorySummary(
            category: .sleep,
            status: .ready,
            smallSummary: "Sleep is improving",
            largeSummary: "Your sleep patterns have been consistent this week.",
            lastUpdated: Date()
        )
    )
    .environment(AppSession())
}
