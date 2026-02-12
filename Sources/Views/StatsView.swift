import SwiftUI
import Charts

/// Displays usage stats: streak counter, today's summary, 30-day heat map, and 7-day chart.
struct StatsView: View {
    let dailyPeaks: [(date: Date, peak: Double)]
    let currentStreak: Int
    let activeDays: [Date: Double]
    let todaySessionCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Streak and today's stats row
            HStack(spacing: 12) {
                // Streak
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(currentStreak > 0 ? (AppSettings.shared.activeTheme == .classic ? ColorTheme.brand : Color.orange) : Color.gray.opacity(0.3))
                    Text("\(currentStreak)")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                    Text("day streak")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Text("Last 30 Days")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    if todaySessionCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 4))
                                .foregroundStyle(.tertiary)
                            Text("\(todaySessionCount) sessions")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
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
    private let weekdayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    /// 5 rows × 7 columns, weeks starting on Monday. Future days are nil.
    private var dayGrid: [Date?] {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        // weekday: Sun=1 Mon=2 ... Sat=7 → offset from Monday: Mon=0 Tue=1 ... Sun=6
        let daysSinceMonday = (weekday + 5) % 7
        let thisMonday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today)!
        let gridStart = calendar.date(byAdding: .day, value: -28, to: thisMonday)!

        return (0..<35).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: gridStart)!
            return date <= today ? date : nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Weekday labels
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(weekdayLabels.indices, id: \.self) { i in
                    Text(weekdayLabels[i])
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.quaternary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(dayGrid.indices, id: \.self) { i in
                    if let day = dayGrid[i] {
                        let peak = activeDays[calendar.startOfDay(for: day)]
                        RoundedRectangle(cornerRadius: 2)
                            .fill(heatColor(for: peak))
                            .frame(height: 10)
                            .help(dayTooltip(day: day, peak: peak))
                    } else {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.clear)
                            .frame(height: 10)
                    }
                }
            }
        }
    }

    private func heatColor(for peak: Double?) -> Color {
        guard let peak = peak else { return Color.primary.opacity(0.05) }
        switch AppSettings.shared.activeTheme {
        case .classic:
            if peak >= 75 { return ColorTheme.brandDark.opacity(0.8) }
            if peak >= 50 { return ColorTheme.brand.opacity(0.7) }
            if peak >= 25 { return ColorTheme.brandLight.opacity(0.7) }
            return ColorTheme.brandLighter.opacity(0.6)
        case .colorful:
            if peak >= 75 { return .red.opacity(0.7) }
            if peak >= 50 { return .orange.opacity(0.6) }
            if peak >= 25 { return .yellow.opacity(0.5) }
            return .green.opacity(0.4)
        }
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

    private func lastPeakLabel(_ date: Date) -> String {
        Calendar.current.isDateInToday(date) ? "Today" : date.formatted(.dateTime.weekday(.wide))
    }

    private var theme: ColorTheme { AppSettings.shared.activeTheme }

    private func peakColor(for value: Double) -> Color {
        switch theme {
        case .classic:
            if value >= 75 { return ColorTheme.brandDark }
            if value >= 50 { return ColorTheme.brand }
            if value >= 25 { return ColorTheme.brandLight }
            return ColorTheme.brandLighter
        case .colorful:
            if value >= 75 { return .red }
            if value >= 50 { return .orange }
            if value >= 25 { return .yellow }
            return .green
        }
    }

    private var heatGradient: LinearGradient {
        switch theme {
        case .classic:
            return .linearGradient(
                stops: [
                    .init(color: ColorTheme.brandLighter.opacity(0.4), location: 0),
                    .init(color: ColorTheme.brandLight.opacity(0.5), location: 0.25),
                    .init(color: ColorTheme.brand.opacity(0.6), location: 0.5),
                    .init(color: ColorTheme.brandDark.opacity(0.7), location: 0.75),
                ],
                startPoint: .bottom,
                endPoint: .top
            )
        case .colorful:
            return .linearGradient(
                stops: [
                    .init(color: .green.opacity(0.4), location: 0),
                    .init(color: .yellow.opacity(0.5), location: 0.25),
                    .init(color: .orange.opacity(0.6), location: 0.5),
                    .init(color: .red.opacity(0.7), location: 0.75),
                ],
                startPoint: .bottom,
                endPoint: .top
            )
        }
    }

    private var areaGradient: LinearGradient {
        switch theme {
        case .classic:
            return .linearGradient(
                stops: [
                    .init(color: ColorTheme.brandLighter.opacity(0.05), location: 0),
                    .init(color: ColorTheme.brandLight.opacity(0.15), location: 0.25),
                    .init(color: ColorTheme.brand.opacity(0.2), location: 0.5),
                    .init(color: ColorTheme.brand.opacity(0.25), location: 0.75),
                    .init(color: ColorTheme.brandDark.opacity(0.3), location: 1.0),
                ],
                startPoint: .bottom,
                endPoint: .top
            )
        case .colorful:
            return .linearGradient(
                stops: [
                    .init(color: .green.opacity(0.05), location: 0),
                    .init(color: .green.opacity(0.15), location: 0.25),
                    .init(color: .yellow.opacity(0.2), location: 0.5),
                    .init(color: .orange.opacity(0.25), location: 0.75),
                    .init(color: .red.opacity(0.3), location: 1.0),
                ],
                startPoint: .bottom,
                endPoint: .top
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Text("7-Day Usage")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let lastPeak = dailyPeaks.last {
                    Text("\(lastPeakLabel(lastPeak.date)): \(Int(lastPeak.peak))%")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Chart(dailyPeaks, id: \.date) { item in
                AreaMark(
                    x: .value("Day", item.date, unit: .day),
                    y: .value("Peak", item.peak)
                )
                .foregroundStyle(areaGradient)

                LineMark(
                    x: .value("Day", item.date, unit: .day),
                    y: .value("Peak", item.peak)
                )
                .foregroundStyle(heatGradient)
                .lineStyle(StrokeStyle(lineWidth: 1.5))

                if item.date == dailyPeaks.last?.date {
                    PointMark(
                        x: .value("Day", item.date, unit: .day),
                        y: .value("Peak", item.peak)
                    )
                    .foregroundStyle(peakColor(for: item.peak))
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
                        .foregroundStyle(Color.secondary.opacity(0.5))
                }
            }
            .frame(height: 60)
        }
    }
}
