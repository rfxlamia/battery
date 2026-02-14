import SwiftUI

/// Displays extra/overuse usage information when enabled on the account.
struct ExtraUsageView: View {
    let usedCredits: Double?    // API returns cents
    let monthlyLimit: Double?   // API returns cents
    let utilization: Double?

    /// Convert cents to dollars
    private var usedDollars: Double? { usedCredits.map { $0 / 100.0 } }
    private var limitDollars: Double? { monthlyLimit.map { $0 / 100.0 } }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "dollarsign.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Extra Usage")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let utilization = utilization {
                    Text("\(Int(utilization))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(UsageLevel.from(utilization: utilization).color)
                        .monospacedDigit()
                }
            }

            if let used = usedDollars, let limit = limitDollars, limit > 0 {
                ProgressBarView(value: used / limit, color: barColor)

                HStack {
                    Text(String(format: "$%.2f / $%.2f", used, limit))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Spacer()
                    Text(String(format: "$%.2f remaining", limit - used))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            } else if let used = usedDollars {
                Text(String(format: "$%.2f used", used))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private var barColor: Color {
        guard let utilization = utilization else { return .blue }
        return UsageLevel.from(utilization: utilization).color
    }
}
