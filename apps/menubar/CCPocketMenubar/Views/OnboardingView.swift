import AppKit
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var doctorVM: DoctorViewModel
    var onComplete: () -> Void

    @State private var currentStep = 0

    private var steps: [(icon: String, title: String, description: String)] {
        [
            ("hand.wave.fill", String(localized: "Welcome to CC Pocket"), String(localized: "Manage your Bridge Server, monitor usage, and connect your mobile device — all from the menu bar.")),
            ("stethoscope", String(localized: "Environment Check"), String(localized: "Let's make sure everything is set up correctly.")),
            ("checkmark.seal.fill", String(localized: "You're All Set!"), String(localized: "Your environment is ready. You can always re-run Doctor from the Doctor tab if needed.")),
        ]
    }

    /// Whether there are any failing checks that have setup commands.
    private var hasFailingChecks: Bool {
        guard let report = doctorVM.report else { return false }
        return report.results.contains { $0.status == "fail" || $0.status == "warn" }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Step indicator
            HStack(spacing: 6) {
                ForEach(0..<steps.count, id: \.self) { index in
                    Capsule()
                        .fill(index <= currentStep ? Color.accentColor : .white.opacity(0.15))
                        .frame(width: index == currentStep ? 20 : 8, height: 4)
                        .animation(.smooth, value: currentStep)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 16)

            if currentStep < 2 {
                // Welcome / Doctor steps
                VStack(spacing: 12) {
                    Image(systemName: steps[currentStep].icon)
                        .font(.system(size: 40))
                        .foregroundStyle(Color.accentColor)
                        .symbolEffect(.bounce, value: currentStep)

                    Text(steps[currentStep].title)
                        .font(.title3.weight(.semibold))

                    Text(steps[currentStep].description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 16)

                if currentStep == 1 {
                    doctorCheckContent
                }

                Spacer()

                // Navigation buttons
                HStack {
                    if currentStep > 0 {
                        Button("Back") {
                            withAnimation { currentStep -= 1 }
                        }
                        .buttonStyle(.borderless)
                    }

                    Spacer()

                    if currentStep == 0 {
                        Button("Get Started") {
                            withAnimation { currentStep = 1 }
                            doctorVM.runDoctor()
                        }
                        .buttonStyle(.borderedProminent)
                    } else if currentStep == 1 {
                        Button(doctorVM.allPassed ? "Continue" : "Continue Anyway") {
                            withAnimation { currentStep = 2 }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(doctorVM.isRunning)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

            } else {
                // Final step
                VStack(spacing: 16) {
                    Image(systemName: steps[2].icon)
                        .font(.system(size: 40))
                        .foregroundStyle(.green)
                        .symbolEffect(.bounce, value: currentStep)

                    Text(steps[2].title)
                        .font(.title3.weight(.semibold))

                    Text(steps[2].description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 20)

                Spacer()

                Button("Open CC Pocket") {
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Doctor Check Content (Step 2)

    @ViewBuilder
    private var doctorCheckContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                if doctorVM.isRunning && doctorVM.report == nil {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Running checks…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                } else if let report = doctorVM.report {
                    // Check result rows
                    ForEach(report.results) { check in
                        OnboardingCheckRow(check: check, doctorVM: doctorVM)
                    }

                    // Error / progress
                    if let error = doctorVM.actionError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }

                    if let action = doctorVM.actionInProgress {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.mini)
                            Text(action)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Action buttons for failing checks
                    if hasFailingChecks {
                        Divider()
                            .padding(.vertical, 4)

                        HStack(spacing: 8) {
                            Button {
                                doctorVM.openSetupTerminal()
                            } label: {
                                Label(String(localized: "Open Terminal"), systemImage: "terminal")
                                    .font(.caption)
                            }
                            .controlSize(.small)
                            .buttonStyle(.borderedProminent)

                            Spacer()

                            Button {
                                doctorVM.runDoctor()
                            } label: {
                                Label(String(localized: "Re-check"), systemImage: "arrow.clockwise")
                                    .font(.caption)
                            }
                            .controlSize(.small)
                            .buttonStyle(.bordered)
                            .disabled(doctorVM.isRunning)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
    }
}

// MARK: - Onboarding Check Row

private struct OnboardingCheckRow: View {
    let check: CheckResult
    @ObservedObject var doctorVM: DoctorViewModel

    @State private var isExpanded = false

    /// Whether this check has setup commands available.
    private var hasCommands: Bool {
        check.status == "fail" || check.status == "warn"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(spacing: 8) {
                Image(systemName: check.statusIcon)
                    .foregroundStyle(statusColor)
                    .font(.caption)

                Text(check.localizedName)
                    .font(.caption.weight(.medium))

                Spacer()

                if hasCommands {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }

                Text(check.message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard hasCommands else { return }
                withAnimation(.smooth(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }

            // Expanded command block
            if isExpanded && hasCommands {
                VStack(alignment: .leading, spacing: 6) {
                    let commands = doctorVM.setupCommands(for: check)
                    ForEach(Array(commands.enumerated()), id: \.offset) { _, entry in
                        CommandRow(comment: entry.comment, command: entry.command)
                    }
                }
                .padding(.leading, 22)
                .padding(.top, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 6)
        .onAppear {
            // Auto-expand failing checks
            if check.status == "fail" {
                isExpanded = true
            }
        }
    }

    private var statusColor: Color {
        switch check.status {
        case "pass": return .green
        case "fail": return .red
        case "warn": return .orange
        default: return .secondary
        }
    }
}

// MARK: - Command Row (reusable)

struct CommandRow: View {
    let comment: String
    let command: String

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(comment)
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Text(command)
                    .font(.system(.caption2, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(2)

                Spacer(minLength: 4)

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(command, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copied = false
                    }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption2)
                        .frame(width: 16, height: 16)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(copied ? .green : .secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.black.opacity(0.2), in: .rect(cornerRadius: 6))
        }
    }
}
