import SwiftUI

struct QRCodePageView: View {
    @ObservedObject var viewModel: QRCodeViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // QR Code card
                if let image = viewModel.qrImage {
                    VStack(spacing: 12) {
                        Image(nsImage: image)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 180, height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Text("Scan with CC Pocket app")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
                } else {
                    ContentUnavailableView {
                        Label("No Network", systemImage: "wifi.slash")
                    } description: {
                        Text("No network addresses found.")
                    }
                }

                // Deep link with copy
                if !viewModel.deepLink.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "link")
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        Text(viewModel.deepLink)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer()

                        Button {
                            viewModel.copyDeepLink()
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .help("Copy deep link")
                    }
                    .padding(.horizontal, 4)
                }

                // Address list
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.addresses) { address in
                        AddressRow(
                            address: address,
                            isSelected: viewModel.selectedAddress?.ip == address.ip
                        ) {
                            viewModel.selectAddress(address)
                        }
                    }
                }
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
            }
            .padding(16)
        }
        .onAppear {
            viewModel.refresh()
        }
    }
}
