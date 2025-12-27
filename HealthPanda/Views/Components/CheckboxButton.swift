//
//  CheckboxButton.swift
//  HealthPanda
//
//  Checkbox-style button that displays a check or X indicator based on state.
//  Extends the BaseButton pattern with status indicator functionality.
//
//  Hierarchy:
//  - BaseButton: Provides common button styling
//  - CheckboxButton: Adds check/X indicator and state management
//

import SwiftUI

// MARK: - Checkbox State

/// The state of a checkbox button.
enum CheckboxState {
    case unchecked
    case checked
    case failed

    /// SF Symbol name for this state
    var iconName: String {
        switch self {
        case .unchecked: return "circle"
        case .checked: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    /// Color for the state indicator
    var iconColor: Color {
        switch self {
        case .unchecked: return .secondary
        case .checked: return .green
        case .failed: return .red
        }
    }
}

// MARK: - Checkbox Button View

/// A button with a check/X indicator on the trailing edge.
/// Uses the BaseButton pattern and adds checkbox-specific functionality.
///
/// Usage:
/// ```swift
/// CheckboxButton(
///     title: "Enable Feature",
///     subtitle: "This enables the feature",
///     iconName: "star.fill",
///     iconColor: .yellow,
///     state: isEnabled ? .checked : .unchecked
/// ) {
///     isEnabled.toggle()
/// }
/// ```
struct CheckboxButton: View {

    let title: String
    let subtitle: String
    let iconName: String
    let iconColor: Color
    let state: CheckboxState
    var showWarningWhenUnchecked: Bool = false
    let action: () -> Void

    var body: some View {
        BaseButton(style: buttonStyle) {
            action()
        } label: {
            HStack(spacing: 16) {
                // Leading icon
                leadingIcon

                // Text content
                textContent

                Spacer()

                // State indicator (check, X, or chevron)
                stateIndicator
            }
        }
    }

    // MARK: - Subviews

    private var leadingIcon: some View {
        Image(systemName: iconName)
            .font(.title2)
            .foregroundStyle(iconColor)
            .frame(width: 44, height: 44)
            .background(iconColor.opacity(0.15))
            .clipShape(Circle())
    }

    private var textContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(subtitleColor)
        }
    }

    private var stateIndicator: some View {
        Group {
            switch state {
            case .checked:
                Image(systemName: state.iconName)
                    .foregroundStyle(state.iconColor)
                    .font(.title2)
            case .failed:
                Image(systemName: state.iconName)
                    .foregroundStyle(state.iconColor)
                    .font(.title2)
            case .unchecked:
                if showWarningWhenUnchecked {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.title2)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var buttonStyle: BaseButtonStyle {
        var style = BaseButtonStyle.secondary
        style.isEnabled = state != .checked
        return style
    }

    private var subtitleColor: Color {
        state == .checked ? .green : .secondary
    }
}

// MARK: - Preview

#Preview("Checkbox Button States") {
    VStack(spacing: 16) {
        CheckboxButton(
            title: "Unchecked State",
            subtitle: "Tap to check",
            iconName: "star.fill",
            iconColor: .yellow,
            state: .unchecked
        ) {
            print("Tapped unchecked")
        }

        CheckboxButton(
            title: "Checked State",
            subtitle: "Already checked",
            iconName: "heart.fill",
            iconColor: .pink,
            state: .checked
        ) {
            print("Tapped checked")
        }

        CheckboxButton(
            title: "Failed State",
            subtitle: "Something went wrong",
            iconName: "bolt.fill",
            iconColor: .orange,
            state: .failed
        ) {
            print("Tapped failed")
        }

        CheckboxButton(
            title: "With Warning",
            subtitle: "Required field",
            iconName: "exclamationmark.triangle.fill",
            iconColor: .red,
            state: .unchecked,
            showWarningWhenUnchecked: true
        ) {
            print("Tapped warning")
        }
    }
    .padding()
}
