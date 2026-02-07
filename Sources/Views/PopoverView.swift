import SwiftUI

/// Main popover panel shown when clicking the menu bar icon.
struct PopoverView: View {
    @ObservedObject var viewModel: UsageViewModel
    @ObservedObject var updaterService: UpdaterService
    @State private var showSettings = false

    var body: some View {
        if showSettings {
            SettingsView(updaterService: updaterService, onClose: { showSettings = false })
        } else {
            mainContent
        }
    }

    private var mainContent: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Battery")
                    .font(.headline)
                Spacer()
                if let tier = Optional(viewModel.planTier), tier != .unknown {
                    Text(tier.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .clipShape(Capsule())
                }
            }
            .padding(.bottom, 4)

            if let error = viewModel.error {
                // Error state
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                // Session gauge (5-hour)
                SessionGaugeView(
                    title: "Session (5-hour)",
                    utilization: viewModel.sessionUtilization,
                    resetsAt: viewModel.sessionResetsAt,
                    color: viewModel.sessionColor
                )

                Divider()

                // Weekly gauge (7-day)
                WeeklyGaugeView(
                    title: "Weekly (7-day)",
                    utilization: viewModel.weeklyUtilization,
                    resetsAt: viewModel.weeklyResetsAt,
                    color: viewModel.weeklyColor
                )

                // Opus gauge (if applicable)
                if let opusUtil = viewModel.opusUtilization {
                    Divider()
                    WeeklyGaugeView(
                        title: "Opus (7-day)",
                        utilization: opusUtil,
                        resetsAt: viewModel.weeklyResetsAt,
                        color: UsageLevel.from(utilization: opusUtil).color
                    )
                }

                // Extra usage (if enabled)
                if viewModel.extraUsageEnabled {
                    Divider()
                    ExtraUsageView(
                        usedCredits: viewModel.extraUsageCost,
                        monthlyLimit: viewModel.extraUsageLimit,
                        utilization: viewModel.extraUsageUtilization
                    )
                }

                // Projections (Phase 2)
                if viewModel.projection != nil {
                    Divider()
                    ProjectionView(projection: viewModel.projection)
                }

                // Stats: streak, heat map, 7-day chart (Phase 2+3)
                if !viewModel.dailyPeaks.isEmpty || !viewModel.activeDays.isEmpty {
                    Divider()
                    StatsView(
                        dailyPeaks: viewModel.dailyPeaks,
                        currentStreak: viewModel.currentStreak,
                        activeDays: viewModel.activeDays,
                        todaySessionCount: viewModel.todaySessionCount
                    )
                }
            }

            Divider()

            // Footer
            HStack {
                if let lastUpdated = viewModel.lastUpdated {
                    Text("Updated \(TimeFormatting.relativeTime(lastUpdated))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.caption)
                }
                .buttonStyle(.plain)

                Button(action: { viewModel.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)

                Button(action: { updaterService.checkForUpdates() }) {
                    Image(systemName: "arrow.down.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .disabled(!updaterService.canCheckForUpdates)
                .help("Check for Updates")

                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Text("Quit")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
    }
}
