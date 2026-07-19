import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var discovery = BonjourDiscoveryService()
    @State private var isShowingScanner = false

    var body: some View {
        @Bindable var appState = appState

        NavigationStack {
            List {
                Section("Bridge") {
                    TextField("ws://192.168.1.10:8765", text: $appState.connectionURLText)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()

                    SecureField("API 令牌", text: $appState.apiToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    HStack {
                        Button {
                            Task { await appState.connect() }
                        } label: {
                            Label("连接", systemImage: "bolt.horizontal.fill")
                        }
                        .disabled(appState.connectionURLText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Spacer()

                        Button(role: .destructive) {
                            appState.disconnect()
                        } label: {
                            Label("断开", systemImage: "wifi.slash")
                        }
                        .disabled(!appState.connectionState.isConnected)
                    }

                    Button {
                        isShowingScanner = true
                    } label: {
                        Label("扫描二维码", systemImage: "qrcode.viewfinder")
                    }
                }

                Section("Bonjour") {
                    Toggle(isOn: Binding(
                        get: { discovery.isBrowsing },
                        set: { enabled in enabled ? discovery.start() : discovery.stop() }
                    )) {
                        Label("mDNS 发现", systemImage: "dot.radiowaves.left.and.right")
                    }

                    ForEach(discovery.bridges) { bridge in
                        Button {
                            if let url = bridge.urlString {
                                appState.connectionURLText = url
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(bridge.name)
                                Text(bridge.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .disabled(bridge.urlString == nil)
                    }
                }

                Section("运行状态") {
                    LabeledContent("连接", value: appState.connectionState.title)
                    if let bridgeVersion = appState.bridgeVersion {
                        LabeledContent("Bridge", value: bridgeVersion)
                    }
                    LabeledContent("运行中会话", value: "\(appState.sessions.count)")
                    LabeledContent("最近会话", value: "\(appState.recentSessions.count)")
                }

                Section("创作者") {
                    LabeledContent("名字", value: "Alex")
                }

                Section("调试日志") {
                    if appState.logs.isEmpty {
                        Text("暂无日志。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(appState.logs) { entry in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.message)
                                Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("设置")
            .sheet(isPresented: $isShowingScanner) {
                NavigationStack {
                    QRCodeScannerView { value in
                        if let params = ConnectionURLParser.parse(value) {
                            appState.applyDeepLink(params)
                            isShowingScanner = false
                        }
                    }
                    .ignoresSafeArea()
                    .navigationTitle("扫描 Bridge 二维码")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("完成") { isShowingScanner = false }
                        }
                    }
                }
            }
        }
    }
}
