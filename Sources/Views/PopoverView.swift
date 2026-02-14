import SwiftUI

/// Main popover panel shown when clicking the menu bar icon.
struct PopoverView: View {
    @ObservedObject var viewModel: UsageViewModel
    @ObservedObject var updaterService: UpdaterService
    @State private var showSettings = false

    var body: some View {
        Group {
            if showSettings {
                SettingsView(updaterService: updaterService, usageViewModel: viewModel, onClose: { showSettings = false })
            } else if viewModel.needsLogin {
                LoginView(viewModel: viewModel)
            } else {
                mainContent
            }
        }
        .animation(.none, value: showSettings)
        .animation(.none, value: viewModel.needsLogin)
    }

    private var mainContent: some View {
        VStack(spacing: 16) {
            // Account tabs (only when multiple accounts)
            if viewModel.accounts.count > 1 {
                AccountTabsView(
                    accounts: viewModel.accounts,
                    selectedAccountId: viewModel.selectedAccountId,
                    onSelect: { viewModel.selectAccount(id: $0) },
                    onAddAccount: {
                        NSApp.keyWindow?.close()
                        viewModel.startOAuthLogin { _ in }
                    }
                )
            }

            // Header
            HStack {
                Text("Claude Battery")
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

            if let error = viewModel.error, !viewModel.isConnected {
                // Error state (only when we have no data at all)
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
                // Session gauge (5-hour) or no active session
                if viewModel.sessionResetsAt != nil {
                    SessionGaugeView(
                        title: "Session (5-hour)",
                        utilization: viewModel.sessionUtilization,
                        resetsAt: viewModel.sessionResetsAt,
                        color: viewModel.sessionColor
                    )
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text("No active session")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }

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
                    ProjectionView(projection: viewModel.projection, sessionResetsAt: viewModel.sessionResetsAt)
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
                .focusable(false)

                Button(action: { viewModel.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .focusable(false)

                Button(action: { updaterService.checkForUpdates() }) {
                    Image(systemName: "arrow.down.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .disabled(!updaterService.canCheckForUpdates)
                .help("Check for Updates")
                .focusable(false)

                QuitButton()
            }
        }
        .padding(16)
        .animation(.none, value: viewModel.selectedAccountId)
        .background(AppSettings.shared.activeTheme.popoverBackground)
    }
}
