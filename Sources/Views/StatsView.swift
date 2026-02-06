import SwiftUI
import Charts

/// Displays a 7-day usage sparkline chart with daily peak utilization.
struct StatsView: View {
    let dailyPeaks: [(date: Date, peak: Double)]

    var body: some View {
        if dailyPeaks.isEmpty {
            EmptyView()
        } else {
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

                    // Show dot on the last (today's) data point
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
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(height: 60)
            }
        }
    }
}
