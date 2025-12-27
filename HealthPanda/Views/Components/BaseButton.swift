//
//  BaseButton.swift
//  HealthPanda
//
//  Base button component providing common styling and configuration.
//  Uses SwiftUI's compositional pattern for reusable UI components.
//
//  Design Pattern:
//  - BaseButton provides the foundation with common styling
//  - Specialized buttons (CheckboxButton, etc.) wrap BaseButton and add functionality
//  - This follows SwiftUI's compositional approach rather than class inheritance
//

import SwiftUI

// MARK: - Button Style Configuration

/// Configuration for base button appearance.
/// Centralizes styling properties for consistent design across the app.
struct BaseButtonStyle {
    var backgroundColor: Color = Color(.secondarySystemBackground)
    var foregroundColor: Color = .primary
    var cornerRadius: CGFloat = 14
    var horizontalPadding: CGFloat = 16
    var verticalPadding: CGFloat = 16
    var isEnabled: Bool = true

    /// Preset style for primary action buttons
    static var primary: BaseButtonStyle {
        BaseButtonStyle(
            backgroundColor: .accentColor,
            foregroundColor: .white
        )
    }

    /// Preset style for secondary/card-style buttons
    static var secondary: BaseButtonStyle {
        BaseButtonStyle()
    }

    /// Preset style for disabled state
    static func disabled(_ style: BaseButtonStyle) -> BaseButtonStyle {
        var copy = style
        copy.backgroundColor = .gray
        copy.isEnabled = false
        return copy
    }
}

// MARK: - Base Button View

/// Base button component with common styling.
/// Provides a consistent foundation for all buttons in the app.
///
/// Usage:
/// ```swift
/// BaseButton(style: .primary) {
///     // action
/// } label: {
///     Text("Tap me")
/// }
/// ```
struct BaseButton<Label: View>: View {

    let style: BaseButtonStyle
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    init(
        style: BaseButtonStyle = .secondary,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.style = style
        self.action = action
        self.label = label
    }

    var body: some View {
        Button(action: action) {
            label()
                .foregroundStyle(style.foregroundColor)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, style.horizontalPadding)
                .padding(.vertical, style.verticalPadding)
                .background(style.backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius))
        }
        .disabled(!style.isEnabled)
        .opacity(style.isEnabled ? 1.0 : 0.6)
    }
}

// MARK: - Convenience Initializers

extension BaseButton where Label == Text {
    /// Convenience initializer for simple text buttons
    init(
        _ title: String,
        style: BaseButtonStyle = .secondary,
        action: @escaping () -> Void
    ) {
        self.style = style
        self.action = action
        self.label = { Text(title).font(.headline) }
    }
}

// MARK: - Preview

#Preview("Base Button Styles") {
    VStack(spacing: 16) {
        BaseButton("Primary Button", style: .primary) {
            print("Primary tapped")
        }

        BaseButton("Secondary Button", style: .secondary) {
            print("Secondary tapped")
        }

        BaseButton("Disabled Button", style: .disabled(.primary)) {
            print("This won't fire")
        }

        BaseButton(style: .secondary) {
            print("Custom label tapped")
        } label: {
            HStack {
                Image(systemName: "star.fill")
                Text("Custom Label")
                    .font(.headline)
            }
        }
    }
    .padding()
}
