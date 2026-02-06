import Foundation
import UserNotifications

/// Manages macOS native notifications for usage threshold alerts.
class NotificationService {
    private var notifiedThresholds: Set<Int> = []

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    func checkAndNotify(sessionUtilization: Double, weeklyUtilization: Double) {
        let thresholds = [80, 90, 95]
        for threshold in thresholds {
            if sessionUtilization >= Double(threshold) && !notifiedThresholds.contains(threshold) {
                sendNotification(
                    title: "Session Usage at \(threshold)%",
                    body: "Your 5-hour Claude Code session is at \(Int(sessionUtilization))% utilization."
                )
                notifiedThresholds.insert(threshold)
            }
        }
    }

    func resetThresholds(below utilization: Double) {
        notifiedThresholds = notifiedThresholds.filter { Double($0) <= utilization }
    }

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
