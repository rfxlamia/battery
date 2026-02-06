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

    func pruneOldData(olderThan date: Date) throws {
        guard let db = db else { return }
        let old = snapshots.filter(colTimestamp < date.timeIntervalSince1970)
        try db.run(old.delete())
    }

}
