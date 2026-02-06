import SwiftUI

/// Displays the 5-hour session usage with a circular gauge and countdown.
struct SessionGaugeView: View {
    let title: String
    let utilization: Double
    let resetsAt: Date?
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            // Circular gauge
            GaugeRingView(
                value: utilization / 100.0,
                color: color,
                size: 56
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(Int(utilization))%")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
                    .monospacedDigit()

                if let resetsAt = resetsAt {
                    CountdownLabel(targetDate: resetsAt)
                }
            }

            Spacer()
        }
    }
}
