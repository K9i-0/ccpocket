import SwiftUI

struct HeaderView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        HStack(spacing: 10) {
            // Status pill
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.bridgeStatus.color)
                    .frame(width: 7, height: 7)
                    .shadow(color: viewModel.bridgeStatus.color.opacity(0.5), radius: 3)

                Text(viewModel.bridgeStatus.label)
                    .font(.subheadline.weight(.medium))

                if let version = viewModel.bridgeVersion, viewModel.bridgeStatus == .running {
                    Text("v\(version)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .glassEffect(.regular.interactive(), in: .capsule)

            Spacer()

            // Start/Stop button
            Button {
                viewModel.toggleBridge()
            } label: {
                Image(systemName: viewModel.bridgeStatus == .running ? "stop.fill" : "play.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .glassEffect(.regular.interactive(), in: .circle)
            .help(viewModel.bridgeStatus == .running ? "Stop Bridge" : "Start Bridge")
            .disabled(viewModel.bridgeStatus == .checking)
        }
    }
}
