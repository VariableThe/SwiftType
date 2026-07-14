import SwiftUI
import AppKit
import SwiftTypeSystem

/// Onboarding screen displaying privacy guarantees and requesting macOS Accessibility permissions.
public struct OnboardingView: View {
    @State private var isTrusted: Bool = AccessibilityCoordinator.shared.isTrusted
    let onCompleted: () -> Void

    public init(onCompleted: @escaping () -> Void) {
        self.onCompleted = onCompleted
    }

    public var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "keyboard.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .foregroundColor(.accentColor)

            VStack(spacing: 8) {
                Text("Welcome to SwiftType")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Intelligent, Privacy-First System-Wide Autocorrect for macOS")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    icon: "lock.shield.fill",
                    color: .green,
                    title: "100% Offline & Private",
                    description: "All keystrokes and dictionaries remain locally on your Mac in SQLite. No telemetry, no cloud servers."
                )
                FeatureRow(
                    icon: "bolt.fill",
                    color: .orange,
                    title: "Sub-5ms Latency",
                    description: "Powered by SymSpell and BK-Tree algorithmic indexing for instantaneous zero-delay replacement."
                )
                FeatureRow(
                    icon: "chevron.left.forwardslash.chevron.right",
                    color: .blue,
                    title: "Optimized for Developers",
                    description: "Native recognition of programming languages, CLI commands, and technical vocabulary without false corrections."
                )
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.1)))
            .padding(.horizontal, 32)

            Divider()
                .padding(.horizontal, 32)

            VStack(spacing: 12) {
                Text("Accessibility Permissions Required")
                    .font(.headline)
                
                Text("SwiftType requires Accessibility permissions to monitor keystroke boundaries and instantaneously replace typos across macOS applications.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Button(action: requestPermissions) {
                    HStack {
                        Image(systemName: isTrusted ? "checkmark.circle.fill" : "hand.raised.fill")
                        Text(isTrusted ? "Permissions Granted" : "Grant Accessibility Permissions")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(isTrusted ? .green : .accentColor)

                if isTrusted {
                    Button("Continue to SwiftType", action: onCompleted)
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                } else {
                    Button("Check Permissions Status") {
                        isTrusted = AccessibilityCoordinator.shared.isTrusted
                        if isTrusted { onCompleted() }
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(32)
        .frame(width: 580, height: 640)
        .onAppear {
            isTrusted = AccessibilityCoordinator.shared.isTrusted
        }
    }

    private func requestPermissions() {
        _ = AccessibilityCoordinator.shared.requestPermissions(openSystemSettings: true)
        Task { @MainActor in
            for _ in 0..<60 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if AccessibilityCoordinator.shared.isTrusted {
                    self.isTrusted = true
                    break
                }
            }
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}
