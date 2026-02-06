import Foundation

/// App-wide constants.
enum Constants {
    static let apiBaseURL = "https://api.anthropic.com"
    static let tokenRefreshURL = "https://platform.claude.com/v1/oauth/token"
    static let keychainService = "Claude Code-credentials"
    static let betaHeader = "oauth-2025-04-20"

    // Polling intervals (seconds)
    static let defaultPollInterval: TimeInterval = 60
    static let activePollInterval: TimeInterval = 30
    static let idlePollInterval: TimeInterval = 300

    // Notification thresholds
    static let defaultThresholds: [Int] = [80, 90, 95]

    // Database
    static let dataRetentionDays: Int = 90
}
