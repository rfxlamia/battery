import SwiftUI

/// Displays burn rate projections when sufficient data is available.
struct ProjectionView: View {
    let projection: BurnRateProjection?
    let sessionResetsAt: Date?

    var body: some View {
        if let projection = projection, projection.currentRate != 0 {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Projections")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    trendBadge(projection.trend)
                }

                if let limitTime = projection.projectedLimitTime {
                    let remaining = limitTime.timeIntervalSinceNow
                    let limitAfterReset = sessionResetsAt.map { limitTime > $0 } ?? false
                    if remaining > 0 && remaining < 18000 { // Only show if < 5 hours away
                        HStack(spacing: 4) {
                            if limitAfterReset {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                                Text("Limit in \(TimeFormatting.shortDuration(remaining)) (after reset)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(remaining < 1800 ? .red : .orange)
                                Text("Limit in \(TimeFormatting.shortDuration(remaining))")
                                    .font(.caption)
                                    .foregroundStyle(remaining < 1800 ? .red : .primary)
                            }
                        }
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: "arrow.right.circle")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("Projected \(Int(projection.projectedAtReset))% at reset")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "speedometer")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(rateText(projection.currentRate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func trendBadge(_ trend: BurnRateProjection.Trend) -> some View {
        HStack(spacing: 2) {
            Image(systemName: trendSymbol(trend))
                .font(.system(size: 8))
            Text(trend.rawValue.capitalized)
                .font(.system(size: 9))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(trendColor(trend).opacity(0.15))
        .foregroundStyle(trendColor(trend))
        .clipShape(Capsule())
    }

    private func trendSymbol(_ trend: BurnRateProjection.Trend) -> String {
        switch trend {
        case .increasing: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .decreasing: return "arrow.down.right"
        }
    }

    private func trendColor(_ trend: BurnRateProjection.Trend) -> Color {
        switch trend {
        case .increasing: return .orange
        case .stable: return .blue
        case .decreasing: return .green
        }
    }

    private func rateText(_ rate: Double) -> String {
        let absRate = abs(rate)
        if absRate < 0.1 {
            return "Burn rate: minimal"
        }
        return String(format: "Burn rate: %.1f%%/hr", absRate)
    }
}
