//
//  OnboardingView.swift
//  HealthPanda
//
//  Main onboarding screen with permission request buttons.
//  Shows incompatibility message for unsupported devices/regions.
//

import SwiftUI

struct OnboardingView: View {

    @State private var onboardingService = OnboardingService()
    @State private var showAiInstructionsSheet = false

    var body: some View {
        Group {
            if onboardingService.isLoading {
                loadingView
            } else if case .incompatible(let reason) = onboardingService.deviceCompatibility {
                IncompatibleDeviceView(reason: reason)
            } else {
                permissionsView
            }
        }
        .task {
            await onboardingService.loadInitialState()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Getting things ready...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Permissions View

    private var permissionsView: some View {
        VStack(spacing: 0) {
            Spacer()

            // Panda mascot placeholder
            pandaMascotSection

            Spacer()

            // Status message
            Text(onboardingService.statusMessage)
                .font(.title3)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 40)

            // Permission buttons
            VStack(spacing: 16) {
                healthPermissionButton
                aiPermissionButton
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            // "Let's get started!" button - always visible, disabled until ready
            letsGetStartedButton
                .padding(.horizontal, 24)
                .padding(.bottom, 32)

            Spacer()
        }
        .animation(.spring(duration: 0.3), value: onboardingService.canCompleteOnboarding)
        .sheet(isPresented: $showAiInstructionsSheet) {
            AppleIntelligenceInstructionsSheet(
                onOpenSettings: {
                    onboardingService.openAppleIntelligenceSettings()
                },
                onDismiss: {
                    showAiInstructionsSheet = false
                    Task {
                        await onboardingService.confirmAppleIntelligenceEnabled()
                    }
                }
            )
        }
    }

    // MARK: - Panda Mascot Section

    private var pandaMascotSection: some View {
        VStack(spacing: 16) {
            // Placeholder for panda image
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 160, height: 160)

                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.pink)
            }

            Text("Health Panda")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Your personal health companion")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Health Permission Button

    private var healthPermissionButton: some View {
        CheckboxButton(
            title: "Connect Apple Health",
            subtitle: onboardingService.isHealthAuthorized
                ? "Connected"
                : "Access your health data",
            iconName: "heart.fill",
            iconColor: .pink,
            state: onboardingService.isHealthAuthorized ? .checked : .unchecked
        ) {
            Task {
                await onboardingService.requestHealthAuthorization()
            }
        }
    }

    // MARK: - AI Permission Button

    private var aiPermissionButton: some View {
        CheckboxButton(
            title: "Enable Apple Intelligence",
            subtitle: onboardingService.isAiEnabled
                ? "Enabled"
                : "Required for health insights",
            iconName: "sparkles",
            iconColor: onboardingService.isAiEnabled ? .purple : .red,
            state: onboardingService.isAiEnabled ? .checked : .unchecked,
            showWarningWhenUnchecked: true
        ) {
            if !onboardingService.isAiEnabled {
                showAiInstructionsSheet = true
            }
        }
    }

    // MARK: - Let's Get Started Button

    /// Primary CTA button - always visible but disabled until both permissions are granted.
    /// Uses visual feedback to show enabled/disabled state.
    private var letsGetStartedButton: some View {
        Button {
            Task {
                await onboardingService.completeOnboarding()
            }
        } label: {
            HStack(spacing: 8) {
                Text("Let's get started!")
                    .font(.headline)

                Image(systemName: "arrow.right")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(onboardingService.canCompleteOnboarding ? Color.accentColor : Color.gray)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!onboardingService.canCompleteOnboarding)
        .opacity(onboardingService.canCompleteOnboarding ? 1.0 : 0.6)
        .animation(.easeInOut(duration: 0.2), value: onboardingService.canCompleteOnboarding)
    }
}

// MARK: - Incompatible Device View

struct IncompatibleDeviceView: View {

    let reason: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Sad panda placeholder
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 160, height: 160)

                Image(systemName: "heart.slash.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.gray)
            }

            Text("Oh no!")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Health Panda can't run on this device")
                .font(.title3)
                .fontWeight(.medium)

            Text(reason)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            Text("Health Panda requires a device that supports Apple Intelligence (iPhone 15 Pro or newer) and is available in the United States.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
        }
    }
}

// MARK: - Apple Intelligence Instructions Sheet

struct AppleIntelligenceInstructionsSheet: View {

    let onOpenSettings: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Icon
                Image(systemName: "sparkles")
                    .font(.system(size: 60))
                    .foregroundStyle(.purple)
                    .padding(.top, 40)

                Text("Enable Apple Intelligence")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Health Panda uses Apple Intelligence to analyze your health data and provide personalized insights.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // Instructions
                VStack(alignment: .leading, spacing: 16) {
                    InstructionRow(number: 1, text: "Open Settings on your iPhone")
                    InstructionRow(number: 2, text: "Tap \"Apple Intelligence & Siri\"")
                    InstructionRow(number: 3, text: "Turn on Apple Intelligence")
                    InstructionRow(number: 4, text: "Wait for setup to complete, then return here")
                }
                .padding(24)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 24)

                Spacer()

                // Buttons
                VStack(spacing: 12) {
                    Button {
                        onOpenSettings()
                    } label: {
                        Label("Open Settings", systemImage: "gear")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.purple)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button {
                        onDismiss()
                    } label: {
                        Text("I've enabled it")
                            .font(.headline)
                            .foregroundStyle(.purple)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
}

struct InstructionRow: View {

    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Color.purple)
                .clipShape(Circle())

            Text(text)
                .font(.body)
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
}
