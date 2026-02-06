import SwiftUI
import Charts

/// Displays usage stats: streak counter, today's summary, 30-day heat map, and 7-day chart.
struct StatsView: View {
    let dailyPeaks: [(date: Date, peak: Double)]
    let currentStreak: Int
    let activeDays: [Date: Double]
    let todaySnapshotCount: Int
    let todayPeakUtilization: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Streak and today's stats row
            HStack(spacing: 12) {
                // Streak
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(currentStreak > 0 ? Color.orange : Color.gray.opacity(0.3))
                    Text("\(currentStreak)")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                    Text("day streak")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Today's stats
                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                        Text("\(Int(todayPeakUtilization))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 2) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 4))
                            .foregroundStyle(.tertiary)
                        Text("\(todaySnapshotCount) polls")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // 30-day heat map
            if !activeDays.isEmpty {
                HeatMapView(activeDays: activeDays)
            }

            // 7-day sparkline chart
            if !dailyPeaks.isEmpty {
                SparklineChart(dailyPeaks: dailyPeaks)
            }
        }
    }
}

// MARK: - Heat Map

private struct HeatMapView: View {
    let activeDays: [Date: Double]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    private let calendar = Calendar.current

    /// Last 35 days arranged in rows of 7 (weeks), most recent at bottom-right.
    private var dayGrid: [Date] {
        let today = calendar.startOfDay(for: Date())
        // Go back to fill complete weeks (5 rows x 7 cols = 35 days)
        return (0..<35).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Last 30 Days")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
            }

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(dayGrid, id: \.self) { day in
                    let peak = activeDays[calendar.startOfDay(for: day)]
                    RoundedRectangle(cornerRadius: 2)
                        .fill(heatColor(for: peak))
                        .frame(height: 10)
                        .help(dayTooltip(day: day, peak: peak))
                }
            }
        }
    }

    private func heatColor(for peak: Double?) -> Color {
        guard let peak = peak else { return Color.primary.opacity(0.05) }
        if peak >= 75 { return .red.opacity(0.7) }
        if peak >= 50 { return .orange.opacity(0.6) }
        if peak >= 25 { return .yellow.opacity(0.5) }
        return .green.opacity(0.4)
    }

    private func dayTooltip(day: Date, peak: Double?) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateStr = formatter.string(from: day)
        if let peak = peak {
            return "\(dateStr): \(Int(peak))% peak"
        }
        return "\(dateStr): no activity"
    }
}

// MARK: - Sparkline Chart

private struct SparklineChart: View {
    let dailyPeaks: [(date: Date, peak: Double)]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("7-Day Usage")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let todayPeak = dailyPeaks.last {
                    Text("Today: \(Int(todayPeak.peak))%")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Chart(dailyPeaks, id: \.date) { item in
                AreaMark(
                    x: .value("Day", item.date, unit: .day),
                    y: .value("Peak", item.peak)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [.blue.opacity(0.3), .blue.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Day", item.date, unit: .day),
                    y: .value("Peak", item.peak)
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 1.5))

                if item.date == dailyPeaks.last?.date {
                    PointMark(
                        x: .value("Day", item.date, unit: .day),
                        y: .value("Peak", item.peak)
                    )
                    .foregroundStyle(.blue)
                    .symbolSize(20)
                }
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 50, 100]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2]))
                        .foregroundStyle(.quaternary)
                    AxisValueLabel {
                        if let v = value.as(Int.self) {
                            Text("\(v)%")
                                .font(.system(size: 8))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(height: 60)
        }
    }
}
