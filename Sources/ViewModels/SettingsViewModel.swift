import SwiftUI
import ServiceManagement
import UserNotifications

/// View model for the settings panel with launch-at-login and data management.
class SettingsViewModel: ObservableObject {
    let settings = AppSettings.shared

    @Published var notificationPermissionGranted: Bool = false

    init() {
        checkNotificationPermission()
    }

    // MARK: - Launch at Login

    func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                settings.launchAtLogin = enabled
            } catch {
                print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Notifications

    func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationPermissionGranted = settings.authorizationStatus == .authorized
            }
        }
    }

    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Battery Test"
        content.body = "Notifications are working correctly."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "battery-test-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func openNotificationSettings() {
        // Open System Settings > Notifications
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Data

    func clearHistory() async {
        let databaseService = DatabaseService()
        do {
            try await databaseService.initialize()
            try await databaseService.pruneOldData(olderThan: Date())
        } catch {
            print("Failed to clear history: \(error.localizedDescription)")
        }
    }

    func exportData() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "battery-export.json"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task {
                await self.writeExport(to: url)
            }
        }
    }

    private func writeExport(to url: URL) async {
        let databaseService = DatabaseService()
        do {
            try await databaseService.initialize()
            let cutoff = Date().addingTimeInterval(-Double(settings.dataRetentionDays) * 86400)
            let snapshots = try await databaseService.getSnapshots(from: cutoff, to: Date())
            let data = try JSONEncoder().encode(snapshots)
            try data.write(to: url)
        } catch {
            print("Failed to export data: \(error.localizedDescription)")
        }
    }

    // MARK: - App Info

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
