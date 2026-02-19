import Foundation
import Combine

/// Watches `~/.claude/stats-cache.json` for changes and publishes
/// streak, heatmap, sparkline, and session count data derived from it.
class StatsCacheService: ObservableObject {
    @Published var currentStreak: Int = 0
    @Published var activeDays: [Date: Double] = [:]
    @Published var dailyPeaks: [(date: Date, peak: Double)] = []
    @Published var todaySessionCount: Int = 0

    private let filePath: String
    private let projectsPath: String
    private let supplementPath: String
    private var fileDescriptor: Int32 = -1
    private var source: DispatchSourceFileSystemObject?
    private var fallbackTimer: Timer?
    private var refreshTimer: DispatchSourceTimer?

    // In-memory cache for today's live scan
    private var cachedTodayDate: String = ""
    private var cachedTodayFileModDates: [String: Date] = [:]
    private var cachedTodayActivity: StatsCache.DailyActivity?

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.filePath = home.appendingPathComponent(".claude/stats-cache.json").path
        self.projectsPath = home.appendingPathComponent(".claude/projects").path
        self.supplementPath = home.appendingPathComponent(".battery/stats-supplement.json").path
    }

    func startWatching() {
        reload()
        startFileWatcher()
        startRefreshTimer()
    }

    func stopWatching() {
        source?.cancel()
        source = nil
        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
        fallbackTimer?.invalidate()
        fallbackTimer = nil
        refreshTimer?.cancel()
        refreshTimer = nil
    }

    // MARK: - File Watching

    private func startFileWatcher() {
        if FileManager.default.fileExists(atPath: filePath) {
            attachDispatchSource()
        } else {
            // File doesn't exist yet; poll until it appears
            startFallbackTimer()
        }
    }

    private func attachDispatchSource() {
        // Clean up any existing watcher
        source?.cancel()
        source = nil
        if fileDescriptor >= 0 {
            close(fileDescriptor)
        }
        fallbackTimer?.invalidate()
        fallbackTimer = nil

        fileDescriptor = open(filePath, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            startFallbackTimer()
            return
        }

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: .global(qos: .utility)
        )

        src.setEventHandler { [weak self] in
            guard let self = self else { return }
            let flags = src.data
            if flags.contains(.delete) || flags.contains(.rename) {
                // File was replaced (atomic write); re-attach
                self.source?.cancel()
                self.source = nil
                close(self.fileDescriptor)
                self.fileDescriptor = -1
                // Small delay for the new file to appear
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.2) {
                    self.reload()
                    self.attachDispatchSource()
                }
            } else {
                self.reload()
            }
        }

        src.setCancelHandler { [weak self] in
            guard let self = self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }

        self.source = src
        src.resume()
    }

    private func startFallbackTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.fallbackTimer?.invalidate()
            self?.fallbackTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                if FileManager.default.fileExists(atPath: self.filePath) {
                    self.reload()
                    self.attachDispatchSource()
                }
            }
        }
    }

    private func startRefreshTimer() {
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now() + 600, repeating: 600)
        timer.setEventHandler { [weak self] in
            self?.reload()
        }
        self.refreshTimer = timer
        timer.resume()
    }

    // MARK: - Parsing

    func reload() {
        guard let data = FileManager.default.contents(atPath: filePath) else { return }
        guard let cache = try? JSONDecoder().decode(StatsCache.self, from: data) else {
            print("StatsCacheService: Failed to decode stats-cache.json")
            return
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = calendar.timeZone

        // Parse daily activity into date-keyed data
        var parsed: [(date: Date, activity: StatsCache.DailyActivity)] = []
        for entry in cache.dailyActivity {
            if let d = dateFormatter.date(from: entry.date) {
                parsed.append((date: calendar.startOfDay(for: d), activity: entry))
            }
        }

        // Fill gap days from JSONL session files
        supplementFromJSONL(
            after: cache.lastComputedDate,
            into: &parsed,
            calendar: calendar,
            dateFormatter: dateFormatter
        )

        // --- Today's session count ---
        let todaySessions = parsed.first(where: { $0.date == today })?.activity.sessionCount ?? 0

        // --- Current streak (consecutive days backward from today/yesterday) ---
        let activeDateSet = Set(parsed.map(\.date))
        let streak: Int
        if activeDateSet.contains(today) {
            streak = countConsecutiveDays(from: today, activeDates: activeDateSet, calendar: calendar)
        } else {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
            if activeDateSet.contains(yesterday) {
                streak = countConsecutiveDays(from: yesterday, activeDates: activeDateSet, calendar: calendar)
            } else {
                streak = 0
            }
        }

        // --- Active days (last 35 days, normalized by messageCount) ---
        let cutoff35 = calendar.date(byAdding: .day, value: -35, to: today)!
        let recentEntries = parsed.filter { $0.date >= cutoff35 }
        let maxMessages = recentEntries.map(\.activity.messageCount).max() ?? 1
        var days: [Date: Double] = [:]
        for entry in recentEntries {
            let normalized = Double(entry.activity.messageCount) / Double(max(maxMessages, 1)) * 100.0
            days[entry.date] = normalized
        }

        // --- Daily peaks (last 7 days, normalized by messageCount) ---
        let cutoff7 = calendar.date(byAdding: .day, value: -7, to: today)!
        let weekEntries = parsed.filter { $0.date >= cutoff7 }
        let weekByDate = Dictionary(weekEntries.map { ($0.date, $0.activity.messageCount) }, uniquingKeysWith: max)
        let maxWeekMessages = weekByDate.values.max() ?? 1
        var peaks: [(date: Date, peak: Double)] = []
        for dayOffset in -7...0 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            let count = weekByDate[date] ?? 0
            let normalized = Double(count) / Double(max(maxWeekMessages, 1)) * 100.0
            peaks.append((date: date, peak: normalized))
        }

        DispatchQueue.main.async { [weak self] in
            self?.todaySessionCount = todaySessions
            self?.currentStreak = streak
            self?.activeDays = days
            self?.dailyPeaks = peaks
        }
    }

    // MARK: - JSONL Supplement

    /// Persisted supplement for sealed past days + live scan for today.
    private struct PersistedSupplement: Codable {
        let lastComputedDate: String
        var days: [StatsCache.DailyActivity]
    }

    private func supplementFromJSONL(
        after lastComputedDate: String,
        into parsed: inout [(date: Date, activity: StatsCache.DailyActivity)],
        calendar: Calendar,
        dateFormatter: DateFormatter
    ) {
        let todayStr = dateFormatter.string(from: Date())
        let existingDates = Set(parsed.map { dateFormatter.string(from: $0.date) })

        // 1. Load persisted sealed days (past gap days, computed once)
        let sealedDays = loadOrComputeSealedDays(
            lastComputedDate: lastComputedDate,
            todayStr: todayStr,
            dateFormatter: dateFormatter,
            calendar: calendar
        )
        for activity in sealedDays where !existingDates.contains(activity.date) {
            if let d = dateFormatter.date(from: activity.date) {
                parsed.append((date: calendar.startOfDay(for: d), activity: activity))
            }
        }

        // 2. Live scan for today only
        guard !existingDates.contains(todayStr) else { return }
        if let todayActivity = scanTodayFromJSONL(todayStr: todayStr) {
            if let d = dateFormatter.date(from: todayStr) {
                parsed.append((date: calendar.startOfDay(for: d), activity: todayActivity))
            }
        }
    }

    // MARK: Sealed days (persisted to ~/.battery/stats-supplement.json)

    private func loadOrComputeSealedDays(
        lastComputedDate: String,
        todayStr: String,
        dateFormatter: DateFormatter,
        calendar: Calendar
    ) -> [StatsCache.DailyActivity] {
        // Try loading from disk
        if let data = FileManager.default.contents(atPath: supplementPath),
           let persisted = try? JSONDecoder().decode(PersistedSupplement.self, from: data),
           persisted.lastComputedDate == lastComputedDate {
            // Check if we need to seal yesterday (it was "today" last time but is now past)
            let hasAllSealedDays = persisted.days.allSatisfy { $0.date < todayStr }
            let yesterdayStr: String? = {
                guard let today = dateFormatter.date(from: todayStr),
                      let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return nil }
                return dateFormatter.string(from: yesterday)
            }()
            let needsYesterdaySeal = yesterdayStr != nil
                && yesterdayStr! > lastComputedDate
                && !persisted.days.contains(where: { $0.date == yesterdayStr! })

            if hasAllSealedDays && !needsYesterdaySeal {
                return persisted.days
            }
        }

        // Compute sealed days by scanning JSONL for past gap days
        guard let cutoffDate = dateFormatter.date(from: lastComputedDate) else { return [] }
        let cutoffStart = calendar.startOfDay(for: cutoffDate)

        let fm = FileManager.default
        guard let projectDirs = try? fm.contentsOfDirectory(atPath: projectsPath) else { return [] }

        var dayCounts: [String: (messages: Int, toolCalls: Int, sessions: Set<String>)] = [:]

        for dir in projectDirs {
            let dirPath = (projectsPath as NSString).appendingPathComponent(dir)
            guard let files = try? fm.contentsOfDirectory(atPath: dirPath) else { continue }
            for file in files where file.hasSuffix(".jsonl") {
                let fullPath = (dirPath as NSString).appendingPathComponent(file)
                guard let attrs = try? fm.attributesOfItem(atPath: fullPath),
                      let modDate = attrs[.modificationDate] as? Date else { continue }
                if modDate <= cutoffStart { continue }

                let sessionId = (file as NSString).deletingPathExtension
                scanJSONLFile(
                    path: fullPath,
                    cutoffDate: lastComputedDate,
                    onlyDate: nil,
                    excludeDate: todayStr,
                    sessionId: sessionId,
                    into: &dayCounts
                )
            }
        }

        // Build sealed entries
        var sealedDays: [StatsCache.DailyActivity] = []
        for (dateStr, counts) in dayCounts where dateStr < todayStr {
            sealedDays.append(StatsCache.DailyActivity(
                date: dateStr,
                messageCount: counts.messages,
                sessionCount: counts.sessions.count,
                toolCallCount: counts.toolCalls
            ))
        }

        // Persist to disk
        let persisted = PersistedSupplement(lastComputedDate: lastComputedDate, days: sealedDays)
        if let encoded = try? JSONEncoder().encode(persisted) {
            let dir = (supplementPath as NSString).deletingLastPathComponent
            try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
            fm.createFile(atPath: supplementPath, contents: encoded)
        }

        return sealedDays
    }

    // MARK: Today (live scan, cached in memory by file mod dates)

    private func scanTodayFromJSONL(todayStr: String) -> StatsCache.DailyActivity? {
        let fm = FileManager.default
        let todayStart = Calendar.current.startOfDay(for: Date())
        guard let projectDirs = try? fm.contentsOfDirectory(atPath: projectsPath) else { return nil }

        // Collect JSONL files modified today
        var currentModDates: [String: Date] = [:]
        var jsonlFiles: [String] = []

        for dir in projectDirs {
            let dirPath = (projectsPath as NSString).appendingPathComponent(dir)
            guard let files = try? fm.contentsOfDirectory(atPath: dirPath) else { continue }
            for file in files where file.hasSuffix(".jsonl") {
                let fullPath = (dirPath as NSString).appendingPathComponent(file)
                guard let attrs = try? fm.attributesOfItem(atPath: fullPath),
                      let modDate = attrs[.modificationDate] as? Date else { continue }
                if modDate < todayStart { continue }
                currentModDates[fullPath] = modDate
                jsonlFiles.append(fullPath)
            }
        }

        // Reuse cached result if no files changed
        if todayStr == cachedTodayDate,
           currentModDates == cachedTodayFileModDates,
           let cached = cachedTodayActivity {
            return cached
        }

        // Scan only today's entries — use yesterday as cutoff so dateStr > yesterday includes today
        let calendar = Calendar.current
        let yesterdayStr: String = {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            df.timeZone = calendar.timeZone
            return df.string(from: yesterday)
        }()

        var dayCounts: [String: (messages: Int, toolCalls: Int, sessions: Set<String>)] = [:]

        for fullPath in jsonlFiles {
            let sessionId = ((fullPath as NSString).lastPathComponent as NSString).deletingPathExtension
            scanJSONLFile(
                path: fullPath,
                cutoffDate: yesterdayStr,
                onlyDate: todayStr,
                excludeDate: nil,
                sessionId: sessionId,
                into: &dayCounts
            )
        }

        let activity: StatsCache.DailyActivity? = dayCounts[todayStr].map {
            StatsCache.DailyActivity(
                date: todayStr,
                messageCount: $0.messages,
                sessionCount: $0.sessions.count,
                toolCallCount: $0.toolCalls
            )
        }

        cachedTodayDate = todayStr
        cachedTodayFileModDates = currentModDates
        cachedTodayActivity = activity
        return activity
    }

    // MARK: JSONL file scanner

    private func scanJSONLFile(
        path: String,
        cutoffDate: String,
        onlyDate: String?,
        excludeDate: String?,
        sessionId: String,
        into dayCounts: inout [String: (messages: Int, toolCalls: Int, sessions: Set<String>)]
    ) {
        guard let fh = FileHandle(forReadingAtPath: path) else { return }
        defer { fh.closeFile() }

        let bufferSize = 64 * 1024
        var leftover = Data()

        while true {
            let chunk = fh.readData(ofLength: bufferSize)
            if chunk.isEmpty && leftover.isEmpty { break }

            var working = leftover
            working.append(chunk)
            leftover = Data()

            while let newlineIndex = working.firstIndex(of: UInt8(0x0A)) {
                let lineData = working[working.startIndex..<newlineIndex]
                working = working[working.index(after: newlineIndex)...]
                if lineData.isEmpty { continue }
                processJSONLLine(lineData, cutoffDate: cutoffDate, onlyDate: onlyDate, excludeDate: excludeDate, sessionId: sessionId, into: &dayCounts)
            }

            if chunk.isEmpty {
                if !working.isEmpty {
                    processJSONLLine(working, cutoffDate: cutoffDate, onlyDate: onlyDate, excludeDate: excludeDate, sessionId: sessionId, into: &dayCounts)
                }
                break
            }
            leftover = Data(working)
        }
    }

    private func processJSONLLine(
        _ lineData: Data,
        cutoffDate: String,
        onlyDate: String?,
        excludeDate: String?,
        sessionId: String,
        into dayCounts: inout [String: (messages: Int, toolCalls: Int, sessions: Set<String>)]
    ) {
        // Lightweight field extraction — avoid full JSON parse for potentially multi-MB lines.
        // The top-level "type":"assistant" can appear at byte 700-1400 (after nested content types),
        // so we search for exact strings within the first 2KB.
        let searchLimit = min(lineData.count, 2048)
        let searchData = lineData[lineData.startIndex..<lineData.index(lineData.startIndex, offsetBy: searchLimit)]
        guard let searchStr = String(data: searchData, encoding: .utf8) else { return }

        let isUser = searchStr.contains("\"type\":\"user\"")
        let isAssistant = !isUser && searchStr.contains("\"type\":\"assistant\"")
        guard isUser || isAssistant else { return }

        guard let tsRange = searchStr.range(of: "\"timestamp\":\"") else { return }
        let tsStart = tsRange.upperBound
        let tsEndOffset = searchStr.index(tsStart, offsetBy: 10, limitedBy: searchStr.endIndex) ?? searchStr.endIndex
        let dateStr = String(searchStr[tsStart..<tsEndOffset])
        guard dateStr.count == 10, dateStr > cutoffDate else { return }

        if let only = onlyDate, dateStr != only { return }
        if let exclude = excludeDate, dateStr == exclude { return }

        var entry = dayCounts[dateStr] ?? (messages: 0, toolCalls: 0, sessions: Set<String>())
        entry.messages += 1
        entry.sessions.insert(sessionId)

        if isAssistant {
            if let fullLine = String(data: lineData, encoding: .utf8) {
                var searchFrom = fullLine.startIndex
                while let range = fullLine.range(of: "\"type\":\"tool_use\"", range: searchFrom..<fullLine.endIndex) {
                    entry.toolCalls += 1
                    searchFrom = range.upperBound
                }
            }
        }

        dayCounts[dateStr] = entry
    }

    private func countConsecutiveDays(from startDay: Date, activeDates: Set<Date>, calendar: Calendar) -> Int {
        var streak = 0
        var currentDay = startDay
        while activeDates.contains(currentDay) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: currentDay) else { break }
            currentDay = prev
        }
        return streak
    }
}
