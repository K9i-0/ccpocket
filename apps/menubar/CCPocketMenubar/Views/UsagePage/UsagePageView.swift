import SwiftUI

struct UsagePageView: View {
    @ObservedObject var viewModel: UsageViewModel
    let bridgeStatus: BridgeStatus

    var body: some View {
        Group {
            if bridgeStatus != .running {
                ContentUnavailableView {
                    Label("Bridge Not Running",
                          systemImage: "antenna.radiowaves.left.and.right.slash")
                } description: {
                    Text("Start the Bridge Server to view usage data.")
                }
            } else if viewModel.isLoading && viewModel.providers.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.error, viewModel.providers.isEmpty {
                ContentUnavailableView {
                    Label("Unable to Load", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") {
                        viewModel.fetchUsage()
                    }
                }
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        codexUsageCallout

                        ForEach(viewModel.providers) { provider in
                            ProviderUsageCard(provider: provider)
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private var codexUsageCallout: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.9), Color.blue.opacity(0.72)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)

                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Codex usage first")
                        .font(.subheadline.weight(.semibold))
                    Text("Your Codex usage appears at the top so you can quickly check limits before starting from your phone.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
        .padding(16)
        .background(.white.opacity(0.07), in: .rect(cornerRadius: 18))
        .glassEffect(.regular.tint(.white.opacity(0.08)), in: .rect(cornerRadius: 18))
    }
}

private struct ProviderUsageCard: View {
    let provider: UsageInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Provider header
            HStack(spacing: 8) {
                Image(systemName: provider.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(provider.displayName)
                    .font(.headline)

                Spacer()

                if let error = provider.error {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if provider.fiveHour != nil || provider.sevenDay != nil {
                HStack(spacing: 20) {
                    if let fiveHour = provider.fiveHour {
                        UsageGaugeView(
                            label: "5-hour",
                            utilization: fiveHour.utilization,
                            resetsIn: fiveHour.resetsInText
                        )
                    }

                    if let sevenDay = provider.sevenDay {
                        UsageGaugeView(
                            label: "7-day",
                            utilization: sevenDay.utilization,
                            resetsIn: sevenDay.resetsInText
                        )
                    }
                }
                .frame(maxWidth: .infinity)
            } else if provider.error == nil {
                Text("No usage data available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
        }
        .padding(16)
        .background(.white.opacity(0.06), in: .rect(cornerRadius: 14))
    }
}
