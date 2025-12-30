//
//  CategoryDetailView.swift
//  HealthPanda
//
//  Detail view showing full health summary for a category.
//  Handles lazy permission requests and data fetching.
//

import SwiftUI

struct CategoryDetailView: View {
    let category: HealthCategory
    let summary: CategorySummary?
    let healthService: HealthServiceProtocol

    @Environment(\.dismiss) private var dismiss
    @State private var currentSummary: CategorySummary?
    @State private var isLoading = false
    @State private var authStatus: HealthAuthorizationStatus = .notDetermined

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
                        summarySection
                    }
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

    /// Load data for this category, requesting permissions if needed.
    private func loadData() async {
        // Use passed summary if available
        currentSummary = summary

        // Check authorization status for this category
        authStatus = await healthService.checkAuthorizationStatus(for: category)

        // If already authorized, refresh data
        if authStatus == .authorized {
            await refreshData()
        }
    }

    /// Request permissions and then refresh data.
    private func requestPermissionsAndRefresh() async {
        isLoading = true
        defer { isLoading = false }

        // Request authorization for this category
        _ = try? await healthService.requestAuthorization(for: category)
        authStatus = await healthService.checkAuthorizationStatus(for: category)

        // If authorized, fetch data
        if authStatus == .authorized {
            await refreshData()
        }
    }

    /// Refresh data from HealthKit and generate new summary.
    private func refreshData() async {
        isLoading = true
        defer { isLoading = false }

        currentSummary = await healthService.refreshCategory(category)
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
        .background(Color(.secondarySystemBackground))
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
        case .ready: return .green
        case .missingCritical: return .yellow
        case .noData: return .red
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

            Text("To show your \(category.rawValue.lowercased()) insights, Health Panda needs access to your \(category.subtitle.lowercased()) data.")
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
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
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
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Previews

#Preview("Ready") {
    CategoryDetailView(
        category: .heart,
        summary: CategorySummary(
            category: .heart,
            status: .ready,
            smallSummary: "Heart rate trending up 3%",
            largeSummary: "Your heart rate has increased slightly this month compared to last month, averaging 72 BPM versus 70 BPM. Your resting heart rate remains healthy at 58 BPM. Blood oxygen levels are excellent at 98%. Overall, your cardiovascular metrics indicate good heart health.",
            lastUpdated: Date()
        ),
        healthService: HealthService.shared
    )
}

#Preview("No Data") {
    CategoryDetailView(
        category: .heart,
        summary: CategorySummary.noData(for: .heart),
        healthService: HealthService.shared
    )
}
