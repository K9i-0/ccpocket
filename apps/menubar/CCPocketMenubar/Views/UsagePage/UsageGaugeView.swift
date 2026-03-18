import SwiftUI

struct UsageGaugeView: View {
    let label: String
    let utilization: Double
    let resetsIn: String

    private var color: Color {
        if utilization >= 90 { return .red }
        if utilization >= 70 { return .orange }
        return .green
    }

    var body: some View {
        VStack(spacing: 6) {
            Gauge(value: utilization, in: 0...100) {
                EmptyView()
            } currentValueLabel: {
                Text("\(Int(utilization))%")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(color)
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(color)
            .scaleEffect(1.3)
            .frame(width: 70, height: 70)

            Text(label)
                .font(.subheadline.weight(.medium))

            Text("resets in \(resetsIn)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }
}
