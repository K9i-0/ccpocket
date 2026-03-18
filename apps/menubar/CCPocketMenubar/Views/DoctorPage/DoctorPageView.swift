import SwiftUI

struct DoctorPageView: View {
    @ObservedObject var viewModel: DoctorViewModel

    var body: some View {
        Group {
            if viewModel.isRunning && viewModel.report == nil {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Running checks…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let report = viewModel.report {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        // Summary card
                        HStack(spacing: 10) {
                            Image(systemName: report.allRequiredPassed
                                  ? "checkmark.seal.fill" : "xmark.seal.fill")
                                .font(.title3)
                                .foregroundStyle(report.allRequiredPassed ? .green : .red)
                                .symbolEffect(.pulse, options: .repeat(report.allRequiredPassed ? 0 : 3))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(report.allRequiredPassed
                                     ? "All checks passed"
                                     : "Some checks failed")
                                    .font(.subheadline.weight(.semibold))

                                let passCount = report.results.filter { $0.status == "pass" }.count
                                Text("\(passCount)/\(report.results.count) passed")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                viewModel.runDoctor()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 12, weight: .medium))
                                    .frame(width: 26, height: 26)
                            }
                            .buttonStyle(.borderless)
                            .glassEffect(.regular.interactive(), in: .circle)
                            .disabled(viewModel.isRunning)
                        }
                        .padding(14)
                        .glassEffect(.regular, in: .rect(cornerRadius: 12))

                        // Required checks
                        if !viewModel.requiredChecks.isEmpty {
                            checkSection(title: "Required", checks: viewModel.requiredChecks)
                        }

                        // Optional checks
                        if !viewModel.optionalChecks.isEmpty {
                            checkSection(title: "Optional", checks: viewModel.optionalChecks)
                        }

                        // Action status
                        if let actionInProgress = viewModel.actionInProgress {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text(actionInProgress)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 4)
                        }

                        if let error = viewModel.actionError {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(16)
                }
            } else {
                ContentUnavailableView {
                    Label("Doctor", systemImage: "stethoscope")
                } description: {
                    Text("Check your environment setup.")
                } actions: {
                    Button("Run Doctor") {
                        viewModel.runDoctor()
                    }
                }
            }
        }
        .onAppear {
            if viewModel.report == nil {
                viewModel.runDoctor()
            }
        }
    }

    @ViewBuilder
    private func checkSection(title: String, checks: [CheckResult]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 14)
                .padding(.bottom, 6)

            VStack(spacing: 0) {
                ForEach(Array(checks.enumerated()), id: \.element.id) { index, check in
                    if index > 0 {
                        Divider()
                            .padding(.horizontal, 14)
                    }
                    CheckResultRow(check: check, onAction: actionFor(check))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                }
            }
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
        }
    }

    private func actionFor(_ check: CheckResult) -> (() -> Void)? {
        switch check.name {
        case "Node.js" where check.status == "fail":
            return { viewModel.installNode() }
        case "CLI providers" where check.status == "fail":
            return { viewModel.installClaudeCode() }
        case "launchd service" where check.status == "skip":
            return { viewModel.setupBridge() }
        default:
            return nil
        }
    }
}
