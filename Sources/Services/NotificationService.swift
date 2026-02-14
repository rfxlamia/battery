import Foundation
import UserNotifications

/// Manages macOS native notifications for usage threshold alerts.
class NotificationService {
    private var notifiedThresholds: Set<Int> = []
    private var lastProjectionNotification: Date?
    private var lastResetNotification: Date?
    private var previousSessionUtilization: Double?

    private let projectionDebounceInterval: TimeInterval = 1800  // 30 minutes
    private let thresholdDebounceInterval: TimeInterval = 3600   // 1 hour

    /// Track when each threshold was last notified to prevent spam
    private var thresholdNotifiedAt: [Int: Date] = [:]

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    func checkAndNotify(
        sessionUtilization: Double,
        weeklyUtilization: Double,
        projection: BurnRateProjection? = nil,
        sessionResetsAt: Date? = nil,
        settings: AppSettings = .shared
    ) {
        // Threshold-based notifications
        checkThresholds(sessionUtilization: sessionUtilization, settings: settings)

        // Projection-based notification: projected to hit limit within 30 min
        // Skip if the projected limit is after the session reset (usage resets first)
        if let projection = projection, let limitTime = projection.projectedLimitTime {
            let limitAfterReset = sessionResetsAt.map { limitTime > $0 } ?? false
            let remaining = limitTime.timeIntervalSinceNow
            if remaining > 0 && remaining < 1800 && !limitAfterReset {
                if shouldSendProjectionNotification() {
                    sendNotification(
                        title: "Approaching Usage Limit",
                        body: "At current pace, you'll hit the session limit in \(TimeFormatting.shortDuration(remaining))."
                    )
                    lastProjectionNotification = Date()
                }
            }
        }

        // Session reset detection: utilization dropped significantly
        if let previous = previousSessionUtilization,
           previous > 30 && sessionUtilization < 10 {
            if shouldSendResetNotification() {
                sendNotification(
                    title: "Session Reset",
                    body: "Your 5-hour session usage has reset. You're back to \(Int(sessionUtilization))%."
                )
                lastResetNotification = Date()
                // Clear notified thresholds on reset
                notifiedThresholds.removeAll()
                thresholdNotifiedAt.removeAll()
            }
        }

        previousSessionUtilization = sessionUtilization
    }

    func notifyTokenRefreshFailure() {
        sendNotification(
            title: "Credentials Need Attention",
            body: "Battery couldn't refresh your token. Please sign in again from Battery."
        )
    }

    func resetThresholds(below utilization: Double) {
        let toRemove = notifiedThresholds.filter { Double($0) > utilization }
        for threshold in toRemove {
            notifiedThresholds.remove(threshold)
            thresholdNotifiedAt.removeValue(forKey: threshold)
        }
    }

    // MARK: - Private

    private func checkThresholds(sessionUtilization: Double, settings: AppSettings) {
        let activeThresholds: [(Int, Bool)] = [
            (80, settings.notifyAt80),
            (90, settings.notifyAt90),
            (95, settings.notifyAt95),
        ]

        for (threshold, enabled) in activeThresholds {
            guard enabled else { continue }
            if sessionUtilization >= Double(threshold) && !notifiedThresholds.contains(threshold) {
                if shouldSendThresholdNotification(threshold) {
                    sendNotification(
                        title: "Session Usage at \(threshold)%",
                        body: "Your 5-hour Claude Code session is at \(Int(sessionUtilization))% utilization."
                    )
                    notifiedThresholds.insert(threshold)
                    thresholdNotifiedAt[threshold] = Date()
                }
            }
        }
    }

    private func shouldSendThresholdNotification(_ threshold: Int) -> Bool {
        guard let lastNotified = thresholdNotifiedAt[threshold] else { return true }
        return Date().timeIntervalSince(lastNotified) >= thresholdDebounceInterval
    }

    private func shouldSendProjectionNotification() -> Bool {
        guard let last = lastProjectionNotification else { return true }
        return Date().timeIntervalSince(last) >= projectionDebounceInterval
    }

    private func shouldSendResetNotification() -> Bool {
        guard let last = lastResetNotification else { return true }
        return Date().timeIntervalSince(last) >= 300  // 5 min debounce for resets
    }

    func sendNotification(title: String, body: String) {
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
