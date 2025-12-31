//
//  HealthSummaryCard.swift
//  HealthPanda
//
//  Reusable card for displaying health summaries by timespan.
//

import SwiftUI

/// Card displaying a health summary for a specific timespan.
struct HealthSummaryCard: View {
    let timeSpan: TimeSpan
    let loadingState: SummaryLoadingState
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView
            contentView
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 8) {
            Image(systemName: timeSpan.icon)
                .font(.subheadline)
                .foregroundStyle(accentColor)

            Text(timeSpan.rawValue)
                .font(.headline)

            Spacer()

            if let summary = loadingState.summary {
                trendBadge(trend: summary.trend)
            }
        }
    }

    private func trendBadge(trend: TrendDirection) -> some View {
        HStack(spacing: 4) {
            Image(systemName: trend.icon)
                .font(.caption)
            Text(trend.rawValue.capitalized)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(trend.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(trend.color.opacity(0.15))
        .clipShape(Capsule())
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        switch loadingState {
        case .idle, .loading:
            loadingView

        case .loaded(let summary):
            loadedView(summary: summary)

        case .failed:
            errorView
        }
    }

    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Analyzing...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private func loadedView(summary: TimespanSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(timeSpan.comparisonDescription)
                .font(.caption)
                .foregroundStyle(.tertiary)

            Text(summary.summaryText)
                .font(.subheadline)
                .foregroundStyle(.primary)

            if !summary.metricsDisplay.isEmpty {
                Text(summary.metricsDisplay)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var errorView: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            Text("Unable to load data")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}

// MARK: - Previews

#Preview("Loading") {
    HealthSummaryCard(
        timeSpan: .daily,
        loadingState: .loading,
        accentColor: .pink
    )
    .padding()
}

#Preview("Loaded") {
    HealthSummaryCard(
        timeSpan: .daily,
        loadingState: .loaded(TimespanSummary(
            timeSpan: .daily,
            trend: .improving,
            shortSummary: "Your summary is short.",
            summaryText: "Your heart rate is 5% lower today, showing great recovery.",
            metricsDisplay: "68 BPM avg · 55 resting · 98% O₂"
        )),
        accentColor: .pink
    )
    .padding()
}

#Preview("Error") {
    HealthSummaryCard(
        timeSpan: .monthly,
        loadingState: .failed,
        accentColor: .pink
    )
    .padding()
}
