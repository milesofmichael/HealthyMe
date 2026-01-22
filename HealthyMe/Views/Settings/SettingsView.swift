//
//  SettingsView.swift
//  HealthyMe
//
//  Settings screen with app information, legal links, and demo mode toggle.
//  Uses Tile components for consistent styling with the rest of the app.
//

import SwiftUI

struct SettingsView: View {
    // Session for demo mode toggle
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var showingPrivacyPolicy = false

    private let privacyPolicyURL = URL(string: "https://milesofmichael.github.io/HealthyMe/privacy")!
    private let issuesURL = URL(string: "https://github.com/milesofmichael/HealthyMe/issues")!
    private let sourceCodeURL = URL(string: "https://github.com/milesofmichael/HealthyMe")!
    private let logger: LoggerServiceProtocol = LoggerService.shared

    var body: some View {
        @Bindable var session = session

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
                            logger.info("Settings: Opening privacy policy")
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
                            logger.info("Settings: Opening GitHub Issues")
                            openURL(issuesURL)
                        }

                        Tile(
                            icon: "chevron.left.forwardslash.chevron.right",
                            iconColor: .secondary,
                            title: "View Source Code",
                            subtitle: "HealthyMe is open source"
                        ) {
                            logger.info("Settings: Opening source code repo")
                            openURL(sourceCodeURL)
                        }
                    }

                    // MARK: - Developer Section
                    SettingsSection(title: "Developer") {
                        SwitchTile(
                            icon: "play.circle.fill",
                            iconColor: .categoryPerformance,
                            title: "Demo Mode",
                            subtitle: "Show sample health data",
                            isOn: $session.isDemoMode
                        )
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
            .onAppear {
                logger.info("Settings: View appeared")
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
        .environment(AppSession())
}
