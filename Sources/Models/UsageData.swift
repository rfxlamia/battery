import Foundation

// MARK: - API Response Models

struct UsageResponse: Codable {
    let fiveHour: UsageBucket
    let sevenDay: UsageBucket
    let sevenDaySonnet: UsageBucket?
    let sevenDayOpus: UsageBucket?
    let extraUsage: ExtraUsage?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDaySonnet = "seven_day_sonnet"
        case sevenDayOpus = "seven_day_opus"
        case extraUsage = "extra_usage"
    }
}

struct UsageBucket: Codable {
    let utilization: Double
    let resetsAt: String

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }

    /// Parse the ISO 8601 reset time into a Date
    var resetsAtDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: resetsAt) {
            return date
        }
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: resetsAt)
    }
}

struct ExtraUsage: Codable {
    let enabled: Bool
    let currentPeriodCostUsd: Double?

    enum CodingKeys: String, CodingKey {
        case enabled
        case currentPeriodCostUsd = "current_period_cost_usd"
    }
}
