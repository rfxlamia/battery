import SwiftUI

/// Displays the weekly usage with a compact horizontal bar.
struct WeeklyGaugeView: View {
    let title: String
    let utilization: Double
    let resetsAt: Date?
    let color: Color

    private var settings: AppSettings { .shared }

    private var displayPercentage: Int {
        settings.showPercentageRemaining
            ? Int(max(0, 100 - utilization))
            : Int(utilization)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 3) {
                    Text("\(displayPercentage)%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(color)
                        .monospacedDigit()
                    Text(settings.showPercentageRemaining ? "left" : "used")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
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
                CountdownLabel(targetDate: resetsAt, style: .compact, mode: settings.showTimeSinceReset ? .elapsed : .remaining)
            }
        }
    }
}
