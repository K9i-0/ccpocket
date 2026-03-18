import SwiftUI

struct UsagePageView: View {
    @ObservedObject var viewModel: UsageViewModel
    let bridgeStatus: BridgeStatus

    var body: some View {
        Group {
            if bridgeStatus == .stopped {
                ContentUnavailableView {
                    Label("Bridge Not Running", systemImage: "antenna.radiowaves.left.and.right.slash")
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
                        ForEach(viewModel.providers) { provider in
                            ProviderUsageCard(provider: provider)
                        }
                    }
                    .padding(16)
                }
                .refreshable {
                    viewModel.fetchUsage()
                }
            }
        }
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
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }
}
