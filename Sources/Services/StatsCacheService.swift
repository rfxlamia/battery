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
    private var fileDescriptor: Int32 = -1
    private var source: DispatchSourceFileSystemObject?
    private var fallbackTimer: Timer?

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.filePath = home.appendingPathComponent(".claude/stats-cache.json").path
    }

    func startWatching() {
        reload()
        startFileWatcher()
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
        let weekEntries = parsed.filter { $0.date >= cutoff7 }.sorted(by: { $0.date < $1.date })
        let maxWeekMessages = weekEntries.map(\.activity.messageCount).max() ?? 1
        var peaks: [(date: Date, peak: Double)] = []
        for entry in weekEntries {
            let normalized = Double(entry.activity.messageCount) / Double(max(maxWeekMessages, 1)) * 100.0
            peaks.append((date: entry.date, peak: normalized))
        }

        DispatchQueue.main.async { [weak self] in
            self?.todaySessionCount = todaySessions
            self?.currentStreak = streak
            self?.activeDays = days
            self?.dailyPeaks = peaks
        }
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
