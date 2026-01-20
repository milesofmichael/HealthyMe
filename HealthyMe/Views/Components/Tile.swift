//
//  Tile.swift
//  HealthyMe
//
//  Reusable tile component for home screen health categories.
//

import SwiftUI

// MARK: - Tile Style

enum TileStyle {
    case normal
    case warning
    case error

    var backgroundColor: Color {
        switch self {
        case .normal: return .backgroundPrimary
        case .warning: return .statusWarning.opacity(0.15)
        case .error: return .statusError.opacity(0.15)
        }
    }

    var borderColor: Color {
        switch self {
        case .normal: return .borderNormal
        case .warning: return .statusWarning
        case .error: return .statusError
        }
    }
}

// MARK: - Tile View

struct Tile: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let style: TileStyle
    let action: () -> Void

    init(
        icon: String,
        iconColor: Color = .accentColor,
        title: String,
        subtitle: String,
        style: TileStyle = .normal,
        action: @escaping () -> Void = {}
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Leading icon
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(iconColor)
                    .frame(width: 32)

                // Title and subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                // Trailing arrow
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(minHeight: 70)
            .background(style.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style.borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Error Tile

/// Convenience initializer for error state tiles
struct ErrorTile: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    init(
        icon: String = "exclamationmark.triangle.fill",
        title: String,
        subtitle: String,
        action: @escaping () -> Void = {}
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }

    var body: some View {
        Tile(
            icon: icon,
            iconColor: .statusError,
            title: title,
            subtitle: subtitle,
            style: .error,
            action: action
        )
    }
}

// MARK: - Warning Tile

/// Convenience initializer for warning state tiles
struct WarningTile: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    init(
        icon: String = "exclamationmark.triangle.fill",
        title: String,
        subtitle: String,
        action: @escaping () -> Void = {}
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }

    var body: some View {
        Tile(
            icon: icon,
            iconColor: .statusStable,
            title: title,
            subtitle: subtitle,
            style: .warning,
            action: action
        )
    }
}

// MARK: - Previews

#Preview("Tile Styles") {
    VStack(spacing: 16) {
        Tile(
            icon: "heart.fill",
            iconColor: .categoryHeart,
            title: "Heart",
            subtitle: "Heart rate, blood pressure"
        )

        WarningTile(
            icon: "moon.fill",
            title: "Sleep",
            subtitle: "No sleep data available"
        )

        ErrorTile(
            title: "Apple Intelligence",
            subtitle: "Enable in Settings to continue"
        )
    }
    .padding()
}
