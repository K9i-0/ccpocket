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

            if currentStep == 0 {
                welcomeStep
            } else if currentStep == 1 {
                doctorStep
            } else {
                doneStep
            }
        }
    }

    // MARK: - Step 0: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                Image(systemName: steps[0].icon)
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentColor)
                    .symbolEffect(.bounce, value: currentStep)

                Text(steps[0].title)
                    .font(.title3.weight(.semibold))

                Text(steps[0].description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 20)

            Spacer()

            Button("Get Started") {
                withAnimation { currentStep = 1 }
                doctorVM.runDoctor()
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Step 1: Doctor (Main)

    private var doctorStep: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: steps[1].icon)
                    .font(.system(size: 32))
                    .foregroundStyle(Color.accentColor)

                Text(steps[1].title)
                    .font(.title3.weight(.semibold))

                Text(steps[1].description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            // Scrollable step list
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if doctorVM.isRunning && doctorVM.report == nil {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Running checks…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 16)
                    } else if let report = doctorVM.report {
                        setupStepList(report: report)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }

            // Fixed bottom bar
            bottomBar
        }
    }

    // MARK: - Step List (flattened numbered steps)

    @ViewBuilder
    private func setupStepList(report: DoctorReport) -> some View {
        let allSteps = buildStepList(report: report)

        ForEach(Array(allSteps.enumerated()), id: \.offset) { index, step in
            switch step {
            case .command(let comment, let command):
                numberedCommandRow(number: index + 1, comment: comment, command: command)
                    .padding(.vertical, 4)
            case .passed(let name, let message):
                passedRow(name: name, message: message)
                    .padding(.vertical, 3)
            }
        }

        // Error / progress
        if let error = doctorVM.actionError {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundStyle(.red)
                .padding(.top, 4)
        }

        if let action = doctorVM.actionInProgress {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.mini)
                Text(action)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Row Components

    private func numberedCommandRow(number: Int, comment: String, command: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Color.accentColor, in: .circle)

            VStack(alignment: .leading, spacing: 3) {
                Text(comment)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                CommandRow(command: command) {
                    #if DEBUG
                    doctorVM.markCommandCompleted(command)
                    #endif
                }
            }
        }
    }

    private func passedRow(name: String, message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)

            Text(name)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer()

            Text(message)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Bottom Bar (pinned)

    private var bottomBar: some View {
        VStack(spacing: 8) {
            Divider()

            // Terminal + Re-check (always visible)
            HStack(spacing: 8) {
                Button {
                    doctorVM.openSetupTerminal()
                } label: {
                    Label(String(localized: "Open Terminal"), systemImage: "terminal")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.small)
                .buttonStyle(.bordered)

                Button {
                    doctorVM.runDoctor()
                } label: {
                    Label(String(localized: "Re-check"), systemImage: "arrow.clockwise")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
                .disabled(doctorVM.isRunning)
            }

            // Navigation
            HStack {
                Button("Back") {
                    withAnimation { currentStep -= 1 }
                }
                .buttonStyle(.borderless)
                .font(.caption)

                Spacer()

                Button(doctorVM.allPassed ? String(localized: "Continue") : String(localized: "Continue Anyway")) {
                    withAnimation { currentStep = 2 }
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .disabled(doctorVM.isRunning)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    // MARK: - Step 2: Done

    private var doneStep: some View {
        VStack(spacing: 0) {
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

    // MARK: - Step Builder

    private enum SetupStep {
        case command(comment: String, command: String)
        case passed(name: String, message: String)
    }

    private func buildStepList(report: DoctorReport) -> [SetupStep] {
        var steps: [SetupStep] = []

        for check in report.results {
            let commands = doctorVM.setupCommands(for: check)
            if commands.isEmpty {
                // Pass or no action needed
                steps.append(.passed(name: check.localizedName, message: check.message))
            } else {
                for entry in commands {
                    steps.append(.command(comment: entry.comment, command: entry.command))
                }
            }
        }

        return steps
    }
}

// MARK: - Command Row (reusable)

struct CommandRow: View {
    let command: String
    var onCopied: (() -> Void)?

    @State private var copied = false

    var body: some View {
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
                onCopied?()
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
