import SwiftUI

struct PopoverContentView: View {
    @ObservedObject var viewModel: AppViewModel
    @StateObject private var usageVM = UsageViewModel()
    @StateObject private var qrCodeVM = QRCodeViewModel()
    @StateObject private var doctorVM = DoctorViewModel()

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(viewModel: viewModel)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            TabView(selection: $viewModel.selectedTab) {
                Tab(AppTab.usage.label, systemImage: AppTab.usage.icon, value: .usage) {
                    UsagePageView(viewModel: usageVM, bridgeStatus: viewModel.bridgeStatus)
                }

                Tab(AppTab.qrCode.label, systemImage: AppTab.qrCode.icon, value: .qrCode) {
                    QRCodePageView(viewModel: qrCodeVM)
                }

                Tab(AppTab.doctor.label, systemImage: AppTab.doctor.icon, value: .doctor) {
                    DoctorPageView(viewModel: doctorVM)
                }
            }
            .tabViewStyle(.sidebarAdaptable)
        }
        .frame(width: 380, height: 500)
        .onChange(of: viewModel.selectedTab) { _, newTab in
            switch newTab {
            case .usage:
                usageVM.fetchUsage()
            case .qrCode:
                qrCodeVM.refresh()
            case .doctor:
                if doctorVM.report == nil {
                    doctorVM.runDoctor()
                }
            }
        }
        .onAppear {
            usageVM.startAutoRefresh()
        }
        .onDisappear {
            usageVM.stopAutoRefresh()
        }
    }
}
