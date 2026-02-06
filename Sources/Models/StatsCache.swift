import Foundation

/// Codable model matching Claude Code's `~/.claude/stats-cache.json` structure.
struct StatsCache: Codable {
    let version: Int
    let lastComputedDate: String
    let dailyActivity: [DailyActivity]
    let totalSessions: Int
    let totalMessages: Int

    struct DailyActivity: Codable {
        let date: String  // "YYYY-MM-DD"
        let messageCount: Int
        let sessionCount: Int
        let toolCallCount: Int
    }
}
