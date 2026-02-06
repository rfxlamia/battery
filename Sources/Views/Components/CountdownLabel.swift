import SwiftUI

/// Displays a live countdown to a target date, updating every second.
struct CountdownLabel: View {
    let targetDate: Date
    var style: CountdownStyle = .full

    enum CountdownStyle {
        case full     // "2h 13m remaining"
        case compact  // "2h 13m"
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = targetDate.timeIntervalSince(context.date)
            if remaining > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(formattedTime(remaining))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    if style == .full {
                        Text("remaining")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            } else {
                Text("Resetting...")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }

    private func formattedTime(_ interval: TimeInterval) -> String {
        TimeFormatting.shortDuration(interval)
    }
}
