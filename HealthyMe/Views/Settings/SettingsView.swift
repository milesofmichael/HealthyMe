//
//  SettingsView.swift
//  HealthyMe
//
//  Settings screen with app information and legal links.
//  Uses Tile components for consistent styling with the rest of the app.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingPrivacyPolicy = false

    private let privacyPolicyURL = URL(string: "https://milesofmichael.github.io/HealthyMe/privacy")!
    private let issuesURL = URL(string: "https://github.com/milesofmichael/HealthyMe/issues")!
    private let sourceCodeURL = URL(string: "https://github.com/milesofmichael/HealthyMe")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - About Section
                    SettingsSection(title: "About") {
                        Tile(
                            icon: "hand.raised.fill",
                            iconColor: .accentColor,
                            title: "Privacy Policy",
                            subtitle: "How we handle your health data"
                        ) {
                            showingPrivacyPolicy = true
                        }
                    }

                    // MARK: - Support Section
                    SettingsSection(title: "Support") {
                        Tile(
                            icon: "ladybug.fill",
                            iconColor: .statusError,
                            title: "Report an Issue",
                            subtitle: "Open a bug report on GitHub"
                        ) {
                            openURL(issuesURL)
                        }

                        Tile(
                            icon: "chevron.left.forwardslash.chevron.right",
                            iconColor: .secondary,
                            title: "View Source Code",
                            subtitle: "HealthyMe is open source"
                        ) {
                            openURL(sourceCodeURL)
                        }
                    }
                }
                .padding()
            }
            .background(Color.backgroundSecondary)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingPrivacyPolicy) {
                WebView(url: privacyPolicyURL, title: "Privacy Policy")
            }
        }
    }

    private func openURL(_ url: URL) {
        UIApplication.shared.open(url)
    }
}

// MARK: - Settings Section

/// A reusable section container for grouping settings tiles.
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 8) {
                content
            }
        }
    }
}

#Preview {
    SettingsView()
}
