import SwiftUI

struct GitView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Git 控制会在第二阶段实现。", systemImage: "point.3.connected.trianglepath.dotted")
                        .foregroundStyle(.secondary)
                    Text("原生客户端已经保留了这个 Tab，后续可以直接加入 diff、stage、commit 和 push，不需要改变主信息架构。")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Git")
        }
    }
}
