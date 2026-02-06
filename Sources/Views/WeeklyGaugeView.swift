import SwiftUI

/// Displays the weekly usage with a compact horizontal bar.
struct WeeklyGaugeView: View {
    let title: String
    let utilization: Double
    let resetsAt: Date?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(utilization))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(color)
                    .monospacedDigit()
            }

            // Horizontal progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.quaternary)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geometry.size.width * min(utilization / 100.0, 1.0), height: 6)
                        .animation(.easeInOut(duration: 0.5), value: utilization)
                }
            }
            .frame(height: 6)

            if let resetsAt = resetsAt {
                HStack {
                    Text("Resets in")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    CountdownLabel(targetDate: resetsAt, style: .compact)
                }
            }
        }
    }
}
