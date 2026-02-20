import SwiftUI

/// Displays the 5-hour session usage with a circular gauge and countdown.
struct SessionGaugeView: View {
    let title: String
    let utilization: Double
    let resetsAt: Date?
    let color: Color

    private var settings: AppSettings { .shared }

    var body: some View {
        HStack(spacing: 16) {
            // Circular gauge
            GaugeRingView(
                value: Double(settings.displayPercentage(for: utilization)) / 100.0,
                color: color,
                size: 56
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(settings.displayPercentage(for: utilization))%")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(color)
                        .monospacedDigit()
                    Text(settings.percentageSuffix)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                if let resetsAt = resetsAt {
                    CountdownLabel(targetDate: resetsAt, mode: settings.showTimeSinceReset ? .elapsed : .remaining)
                }
            }

            Spacer()
        }
    }
}
