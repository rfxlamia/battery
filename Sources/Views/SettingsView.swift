import SwiftUI

/// Full settings panel with display, notification, polling, data, general, and about sections.
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var updaterService: UpdaterService
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    displaySection
                    notificationsSection
                    pollingSection
                    dataSection
                    generalSection
                    aboutSection
                }
                .padding(16)
            }
        }
        .frame(width: 320)
    }

    // MARK: - Display

    private var displaySection: some View {
        SettingsSection(title: "Display", icon: "eye") {
            // Menu bar appearance
            VStack(alignment: .leading, spacing: 6) {
                Text("Menu Bar")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Toggle("Show icon", isOn: $settings.showMenuBarIcon)
                    .font(.caption)

                Toggle("Show text", isOn: $settings.showMenuBarText)
                    .font(.caption)

                if settings.showMenuBarText {
                    Picker("Format", selection: Binding(
                        get: { settings.displayMode },
                        set: { settings.displayMode = $0 }
                    )) {
                        ForEach(MenuBarDisplayMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.caption)
                }
            }

            Divider()

            // Value display preferences
            VStack(alignment: .leading, spacing: 6) {
                Text("Values")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Toggle(isOn: $settings.showPercentageRemaining) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Show remaining percentage")
                            .font(.caption)
                        Text(settings.showPercentageRemaining ? "e.g. 51% left" : "e.g. 49% used")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Toggle(isOn: $settings.showTimeSinceReset) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Show time elapsed")
                            .font(.caption)
                        Text(settings.showTimeSinceReset ? "e.g. Started 3h 37m ago" : "e.g. Resets in 1h 23m")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        SettingsSection(title: "Notifications", icon: "bell") {
            if !viewModel.notificationPermissionGranted {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("Notifications disabled")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Enable") {
                        viewModel.openNotificationSettings()
                    }
                    .font(.caption)
                    .controlSize(.small)
                }
            }

            Toggle("Notify at 80%", isOn: $settings.notifyAt80)
                .font(.caption)
            Toggle("Notify at 90%", isOn: $settings.notifyAt90)
                .font(.caption)
            Toggle("Notify at 95%", isOn: $settings.notifyAt95)
                .font(.caption)

            HStack {
                Spacer()
                Button("Test Notification") {
                    viewModel.sendTestNotification()
                }
                .font(.caption)
                .controlSize(.small)
            }
        }
    }

    // MARK: - Polling

    private var pollingSection: some View {
        SettingsSection(title: "Polling", icon: "arrow.clockwise") {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Active interval")
                        .font(.caption)
                    Spacer()
                    Text("\(Int(settings.pollIntervalActive))s")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $settings.pollIntervalActive, in: 15...120, step: 15)
                    .controlSize(.small)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Idle interval")
                        .font(.caption)
                    Spacer()
                    Text("\(Int(settings.pollIntervalIdle / 60))m")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $settings.pollIntervalIdle, in: 60...600, step: 60)
                    .controlSize(.small)
            }

            Text("Active polling is used when a Claude Code session is detected.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        SettingsSection(title: "Data", icon: "cylinder") {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Retention period")
                        .font(.caption)
                    Spacer()
                    Text("\(settings.dataRetentionDays) days")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { Double(settings.dataRetentionDays) },
                        set: { settings.dataRetentionDays = Int($0) }
                    ),
                    in: 7...365,
                    step: 7
                )
                .controlSize(.small)
            }

            HStack(spacing: 8) {
                Button("Export Data") {
                    viewModel.exportData()
                }
                .font(.caption)
                .controlSize(.small)

                Spacer()

                Button("Clear History") {
                    Task { await viewModel.clearHistory() }
                }
                .font(.caption)
                .controlSize(.small)
            }
        }
    }

    // MARK: - General

    private var generalSection: some View {
        SettingsSection(title: "General", icon: "gearshape") {
            Toggle("Launch at login", isOn: Binding(
                get: { settings.launchAtLogin },
                set: { viewModel.setLaunchAtLogin($0) }
            ))
            .font(.caption)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        SettingsSection(title: "About", icon: "info.circle") {
            HStack {
                Text("Battery")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Text("v\(viewModel.appVersion) (\(viewModel.buildNumber))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Claude Code usage monitor for your menu bar.")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            HStack {
                Spacer()
                Button("Check for Updates") {
                    updaterService.checkForUpdates()
                }
                .font(.caption)
                .controlSize(.small)
                .disabled(!updaterService.canCheckForUpdates)
            }
        }
    }
}

// MARK: - Reusable Section Component

private struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding(10)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
