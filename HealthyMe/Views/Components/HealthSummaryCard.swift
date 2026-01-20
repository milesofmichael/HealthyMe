//
//  HealthSummaryCard.swift
//  HealthyMe
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
        .background(Color.backgroundSecondary)
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
        }
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

            // Per-metric trend indicators
            if !summary.metricTrends.isEmpty {
                metricTrendsView(trends: summary.metricTrends)
            }
        }
    }

    /// Displays individual metric trends with color-coded indicators.
    /// Each metric shows its value and a trend arrow (green = improving, red = declining).
    private func metricTrendsView(trends: [MetricTrend]) -> some View {
        // Wrap metrics in rows of 2 for consistent layout
        // O(n) layout where n = number of metrics (typically 2-4)
        let rows = stride(from: 0, to: trends.count, by: 2).map { index in
            Array(trends[index..<min(index + 2, trends.count)])
        }

        return VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.name) { metric in
                        metricTrendItem(metric)
                    }
                    Spacer()
                }
            }
        }
    }

    /// Single metric trend indicator with name, value, and direction arrow.
    private func metricTrendItem(_ metric: MetricTrend) -> some View {
        HStack(spacing: 4) {
            // Trend arrow with semantic color
            Image(systemName: metric.icon)
                .font(.caption2)
                .foregroundStyle(metric.color)

            // Metric name and value
            Text("\(metric.name): \(metric.value)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(metric.color.opacity(0.1))
        .clipShape(Capsule())
    }

    private var errorView: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(Color.statusStable)
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
        accentColor: .categoryHeart
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
            metricsDisplay: "68 BPM avg · 55 resting",
            metricTrends: [
                MetricTrend(name: "Avg HR", value: "68 BPM", direction: .improving),
                MetricTrend(name: "Resting", value: "55 BPM", direction: .improving),
                MetricTrend(name: "HRV", value: "42 ms", direction: .declining),
                MetricTrend(name: "Walking", value: "95 BPM", direction: .stable)
            ]
        )),
        accentColor: .categoryHeart
    )
    .padding()
}

#Preview("Error") {
    HealthSummaryCard(
        timeSpan: .monthly,
        loadingState: .failed,
        accentColor: .categoryHeart
    )
    .padding()
}
