//
//  CategoryDetailView.swift
//  HealthPanda
//
//  Detail view showing full health summary for a category.
//

import SwiftUI

struct CategoryDetailView: View {
    let category: HealthCategory
    let summary: CategorySummary?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    summarySection
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

                if let summary {
                    statusBadge(for: summary.status)
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

    // MARK: - Summary

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.headline)

            if let summary {
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
        )
    )
}

#Preview("No Data") {
    CategoryDetailView(
        category: .heart,
        summary: CategorySummary.noData(for: .heart)
    )
}
