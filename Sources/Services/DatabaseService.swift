import Foundation
import SQLite

/// SQLite-backed persistence for usage history snapshots.
/// Phase 2: Full implementation with schema, CRUD, and pruning.
actor DatabaseService {

    private var db: Connection?

    // Table definition
    private let snapshots = Table("usage_snapshots")
    private let colId = SQLite.Expression<String>("id")
    private let colTimestamp = SQLite.Expression<Double>("timestamp")
    private let colSessionUtil = SQLite.Expression<Double>("session_utilization")
    private let colSessionResets = SQLite.Expression<Double>("session_resets_at")
    private let colWeeklyUtil = SQLite.Expression<Double>("weekly_utilization")
    private let colWeeklyResets = SQLite.Expression<Double>("weekly_resets_at")
    private let colSonnetUtil = SQLite.Expression<Double?>("sonnet_utilization")
    private let colOpusUtil = SQLite.Expression<Double?>("opus_utilization")
    private let colPlanTier = SQLite.Expression<String>("plan_tier")

    func initialize() throws {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let batteryDir = appSupport.appendingPathComponent("Battery", isDirectory: true)
        try FileManager.default.createDirectory(at: batteryDir, withIntermediateDirectories: true)
        let dbPath = batteryDir.appendingPathComponent("battery.db").path
        db = try Connection(dbPath)

        try db?.run(snapshots.create(ifNotExists: true) { t in
            t.column(colId, primaryKey: true)
            t.column(colTimestamp)
            t.column(colSessionUtil)
            t.column(colSessionResets)
            t.column(colWeeklyUtil)
            t.column(colWeeklyResets)
            t.column(colSonnetUtil)
            t.column(colOpusUtil)
            t.column(colPlanTier)
        })

        // Create index on timestamp for efficient range queries
        try db?.run(snapshots.createIndex(colTimestamp, ifNotExists: true))
    }

    func saveSnapshot(_ snapshot: UsageSnapshot) throws {
        guard let db = db else { return }
        try db.run(snapshots.insert(
            colId <- snapshot.id.uuidString,
            colTimestamp <- snapshot.timestamp.timeIntervalSince1970,
            colSessionUtil <- snapshot.sessionUtilization,
            colSessionResets <- snapshot.sessionResetsAt.timeIntervalSince1970,
            colWeeklyUtil <- snapshot.weeklyUtilization,
            colWeeklyResets <- snapshot.weeklyResetsAt.timeIntervalSince1970,
            colSonnetUtil <- snapshot.sonnetUtilization,
            colOpusUtil <- snapshot.opusUtilization,
            colPlanTier <- snapshot.planTier
        ))
    }

    func getSnapshots(from startDate: Date, to endDate: Date) throws -> [UsageSnapshot] {
        guard let db = db else { return [] }
        let query = snapshots
            .filter(colTimestamp >= startDate.timeIntervalSince1970 && colTimestamp <= endDate.timeIntervalSince1970)
            .order(colTimestamp.asc)

        return try db.prepare(query).map { row in
            UsageSnapshot(
                id: UUID(uuidString: row[colId]) ?? UUID(),
                timestamp: Date(timeIntervalSince1970: row[colTimestamp]),
                sessionUtilization: row[colSessionUtil],
                sessionResetsAt: Date(timeIntervalSince1970: row[colSessionResets]),
                weeklyUtilization: row[colWeeklyUtil],
                weeklyResetsAt: Date(timeIntervalSince1970: row[colWeeklyResets]),
                sonnetUtilization: row[colSonnetUtil],
                opusUtilization: row[colOpusUtil],
                planTier: row[colPlanTier]
            )
        }
    }

    func getLatestSnapshots(count: Int) throws -> [UsageSnapshot] {
        guard let db = db else { return [] }
        let query = snapshots
            .order(colTimestamp.desc)
            .limit(count)

        return try db.prepare(query).map { row in
            UsageSnapshot(
                id: UUID(uuidString: row[colId]) ?? UUID(),
                timestamp: Date(timeIntervalSince1970: row[colTimestamp]),
                sessionUtilization: row[colSessionUtil],
                sessionResetsAt: Date(timeIntervalSince1970: row[colSessionResets]),
                weeklyUtilization: row[colWeeklyUtil],
                weeklyResetsAt: Date(timeIntervalSince1970: row[colWeeklyResets]),
                sonnetUtilization: row[colSonnetUtil],
                opusUtilization: row[colOpusUtil],
                planTier: row[colPlanTier]
            )
        }.reversed()  // Return in chronological order
    }

    func getDailyPeaks(days: Int) throws -> [(date: Date, peak: Double)] {
        guard let db = db else { return [] }
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
        let query = snapshots
            .filter(colTimestamp >= cutoff.timeIntervalSince1970)
            .order(colTimestamp.asc)

        // Group by calendar day and find peak session utilization per day
        var dailyPeaks: [String: Double] = [:]
        var dailyDates: [String: Date] = [:]
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for row in try db.prepare(query) {
            let timestamp = Date(timeIntervalSince1970: row[colTimestamp])
            let dayKey = dateFormatter.string(from: timestamp)
            let util = row[colSessionUtil]

            if let existing = dailyPeaks[dayKey] {
                if util > existing {
                    dailyPeaks[dayKey] = util
                }
            } else {
                dailyPeaks[dayKey] = util
                dailyDates[dayKey] = calendar.startOfDay(for: timestamp)
            }
        }

        return dailyDates.keys.sorted().compactMap { key in
            guard let date = dailyDates[key], let peak = dailyPeaks[key] else { return nil }
            return (date: date, peak: peak)
        }
    }

    func pruneOldData(olderThan date: Date) throws {
        guard let db = db else { return }
        let old = snapshots.filter(colTimestamp < date.timeIntervalSince1970)
        try db.run(old.delete())
    }

    /// Returns a set of dates (start-of-day) that have at least one snapshot, going back `days` days.
    func getActiveDays(days: Int) throws -> [Date: Double] {
        guard let db = db else { return [:] }
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
        let query = snapshots
            .filter(colTimestamp >= cutoff.timeIntervalSince1970)
            .order(colTimestamp.asc)

        var dayPeaks: [String: Double] = [:]
        var dayDates: [String: Date] = [:]
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        for row in try db.prepare(query) {
            let timestamp = Date(timeIntervalSince1970: row[colTimestamp])
            let key = formatter.string(from: timestamp)
            let util = row[colSessionUtil]
            if let existing = dayPeaks[key] {
                dayPeaks[key] = max(existing, util)
            } else {
                dayPeaks[key] = util
                dayDates[key] = calendar.startOfDay(for: timestamp)
            }
        }

        var result: [Date: Double] = [:]
        for (key, date) in dayDates {
            result[date] = dayPeaks[key] ?? 0
        }
        return result
    }

    /// Returns the current usage streak (consecutive days with snapshots ending today).
    func getCurrentStreak() throws -> Int {
        let activeDays = try getActiveDays(days: 90)
        guard !activeDays.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Check if today has activity
        guard activeDays[today] != nil else {
            // Check if yesterday had activity (streak might still be live if it's early in the day)
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
            guard activeDays[yesterday] != nil else { return 0 }
            // Count backwards from yesterday
            return countConsecutiveDays(from: yesterday, activeDays: activeDays, calendar: calendar)
        }

        return countConsecutiveDays(from: today, activeDays: activeDays, calendar: calendar)
    }

    private func countConsecutiveDays(from startDay: Date, activeDays: [Date: Double], calendar: Calendar) -> Int {
        var streak = 0
        var currentDay = startDay
        while activeDays[currentDay] != nil {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: currentDay) else { break }
            currentDay = prev
        }
        return streak
    }

    /// Returns today's snapshot count (approximate session count proxy).
    func getTodaySnapshotCount() throws -> Int {
        guard let db = db else { return 0 }
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let query = snapshots.filter(
            colTimestamp >= today.timeIntervalSince1970 && colTimestamp < tomorrow.timeIntervalSince1970
        )
        return try db.scalar(query.count)
    }
}
