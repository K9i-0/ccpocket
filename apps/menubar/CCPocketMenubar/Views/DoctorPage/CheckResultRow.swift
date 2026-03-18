import SwiftUI

struct CheckResultRow: View {
    let check: CheckResult
    let onAction: (() -> Void)?

    private var statusColor: Color {
        switch check.status {
        case "pass": return .green
        case "fail": return .red
        case "warn": return .orange
        default: return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: check.statusIcon)
                    .foregroundStyle(statusColor)
                    .font(.body)
                    .contentTransition(.symbolEffect(.replace))

                Text(check.name)
                    .font(.subheadline.weight(.medium))

                Spacer()

                Text(check.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Provider sub-items
            if let providers = check.providers {
                ForEach(providers) { provider in
                    HStack(spacing: 8) {
                        Image(systemName: providerIcon(provider))
                            .foregroundStyle(providerColor(provider))
                            .font(.caption)

                        Text(provider.name)
                            .font(.caption)

                        Spacer()

                        Text(providerStatus(provider))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 24)
                }
            }

            // Remediation
            if let remediation = check.remediation,
               check.status == "fail" || check.status == "warn" {
                HStack {
                    Text(remediation)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if let action = onAction {
                        Spacer()
                        Button("Fix", action: action)
                            .controlSize(.small)
                            .buttonStyle(.borderedProminent)
                            .tint(.accentColor)
                    }
                }
                .padding(.leading, 24)
            }
        }
    }

    private func providerIcon(_ p: ProviderResult) -> String {
        if !p.installed { return "minus.circle" }
        if !p.authenticated { return "exclamationmark.triangle.fill" }
        return "checkmark.circle.fill"
    }

    private func providerColor(_ p: ProviderResult) -> Color {
        if !p.installed { return .secondary }
        if !p.authenticated { return .orange }
        return .green
    }

    private func providerStatus(_ p: ProviderResult) -> String {
        if !p.installed { return "Not installed" }
        var parts: [String] = []
        if let v = p.version { parts.append(v) }
        parts.append(p.authenticated ? "authenticated" : (p.authMessage ?? "not authenticated"))
        return parts.joined(separator: " · ")
    }
}
