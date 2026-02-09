import SwiftUI
import Combine

/// Main view model that coordinates all services and provides state to views.
class UsageViewModel: ObservableObject {
    // MARK: - Published State

    @Published var sessionUtilization: Double = 0
    @Published var sessionResetsAt: Date?
    @Published var weeklyUtilization: Double = 0
    @Published var weeklyResetsAt: Date?
    @Published var sonnetUtilization: Double?
    @Published var opusUtilization: Double?
    @Published var extraUsageEnabled: Bool = false
    @Published var extraUsageCost: Double?
    @Published var extraUsageLimit: Double?
    @Published var extraUsageUtilization: Double?
    @Published var isConnected: Bool = false
    @Published var lastUpdated: Date?
    @Published var error: String?
    @Published var planTier: PlanTier = .unknown

    // Phase 2: Projections and history
    @Published var projection: BurnRateProjection?
    @Published var dailyPeaks: [(date: Date, peak: Double)] = []

    // Phase 3: Streaks and stats
    @Published var currentStreak: Int = 0
    @Published var activeDays: [Date: Double] = [:]  // last 30 days heat map
    @Published var todaySessionCount: Int = 0

    // Phase 3: Hook-driven session awareness
    @Published var isSessionActive: Bool = false
    @Published var currentSessionStart: Date?

    // MARK: - Services

    private let pollingService = UsagePollingService()
    private let databaseService = DatabaseService()
    private let notificationService = NotificationService()
    private let hookWatcher = HookFileWatcher()
    private let statsCacheService = StatsCacheService()
    private var cancellables = Set<AnyCancellable>()
    private var dbInitialized = false
    private var todayPeakSeen: Double = 0
    private var todayPeakDate: Date = Calendar.current.startOfDay(for: Date())

    // MARK: - Computed Properties

    var sessionTimeRemaining: TimeInterval {
        guard let resetsAt = sessionResetsAt else { return 0 }
        return max(0, resetsAt.timeIntervalSinceNow)
    }

    var weeklyTimeRemaining: TimeInterval {
        guard let resetsAt = weeklyResetsAt else { return 0 }
        return max(0, resetsAt.timeIntervalSinceNow)
    }

    var sessionColor: Color {
        UsageLevel.from(utilization: sessionUtilization).color
    }

    var weeklyColor: Color {
        UsageLevel.from(utilization: weeklyUtilization).color
    }

    var menuBarText: String {
        let settings = AppSettings.shared
        guard settings.showMenuBarText else { return "" }

        let pct = settings.showPercentageRemaining
            ? Int(max(0, 100 - sessionUtilization))
            : Int(sessionUtilization)

        let time: String
        if settings.showTimeSinceReset, let resetsAt = sessionResetsAt {
            // 5-hour window: time since reset = 5h - time remaining
            let elapsed = 18000 - max(0, resetsAt.timeIntervalSinceNow)
            time = TimeFormatting.shortDuration(max(0, elapsed))
        } else {
            time = TimeFormatting.shortDuration(sessionTimeRemaining)
        }

        switch settings.displayMode {
        case .percentageAndTime:
            return "\(pct)% · \(time)"
        case .percentageOnly:
            return "\(pct)%"
        case .timeOnly:
            return time
        case .iconOnly:
            return ""
        }
    }

    var menuBarSymbol: String {
        UsageLevel.from(utilization: sessionUtilization).sfSymbol
    }

    // MARK: - Lifecycle

    init() {
        setupBindings()
        initializeDatabase()
        notificationService.requestPermission()
        pollingService.startPolling()
        hookWatcher.startWatching()
        statsCacheService.startWatching()
    }

    deinit {
        pollingService.stopPolling()
        hookWatcher.stopWatching()
        statsCacheService.stopWatching()
    }

    func refresh() {
        Task {
            await pollingService.pollNow()
        }
    }

    // MARK: - Private

    private func initializeDatabase() {
        Task {
            do {
                try await databaseService.initialize()
                await MainActor.run { dbInitialized = true }
                // Prune old data
                let cutoff = Date().addingTimeInterval(-Double(Constants.dataRetentionDays) * 86400)
                try await databaseService.pruneOldData(olderThan: cutoff)
            } catch {
                print("Database init error: \(error.localizedDescription)")
            }
        }
    }

    private func setupBindings() {
        pollingService.$latestUsage
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] usage in
                self?.updateFromUsage(usage)
            }
            .store(in: &cancellables)

        pollingService.$lastError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.error = error?.localizedDescription
                if error != nil {
                    self?.isConnected = false
                }
            }
            .store(in: &cancellables)

        // Hook watcher: adjust polling rate based on session activity
        hookWatcher.$isSessionActive
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] active in
                guard let self = self else { return }
                self.isSessionActive = active
                let interval = active ? Constants.activePollInterval : Constants.idlePollInterval
                self.pollingService.setInterval(interval)
            }
            .store(in: &cancellables)

        hookWatcher.$currentSessionStart
            .receive(on: DispatchQueue.main)
            .sink { [weak self] start in
                self?.currentSessionStart = start
            }
            .store(in: &cancellables)

        // Forward settings changes so menu bar icon updates immediately
        AppSettings.shared.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // Stats cache: streak, heatmap, sparkline, session count
        statsCacheService.$currentStreak
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentStreak)

        statsCacheService.$activeDays
            .receive(on: DispatchQueue.main)
            .sink { [weak self] days in
                guard let self = self else { return }
                self.activeDays = self.injectTodayActivity(into: days)
            }
            .store(in: &cancellables)

        statsCacheService.$dailyPeaks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] peaks in
                guard let self = self else { return }
                self.dailyPeaks = self.injectTodayPeak(into: peaks)
            }
            .store(in: &cancellables)

        statsCacheService.$todaySessionCount
            .receive(on: DispatchQueue.main)
            .assign(to: &$todaySessionCount)
    }

    private func updateFromUsage(_ usage: UsageResponse) {
        sessionUtilization = usage.fiveHour?.utilization ?? 0
        sessionResetsAt = usage.fiveHour?.resetsAtDate
        weeklyUtilization = usage.sevenDay.utilization
        weeklyResetsAt = usage.sevenDay.resetsAtDate
        sonnetUtilization = usage.sevenDaySonnet?.utilization
        opusUtilization = usage.sevenDayOpus?.utilization
        extraUsageEnabled = usage.extraUsage?.isEnabled ?? false
        extraUsageCost = usage.extraUsage?.usedCredits
        extraUsageLimit = usage.extraUsage?.monthlyLimit
        extraUsageUtilization = usage.extraUsage?.utilization
        isConnected = true
        lastUpdated = Date()
        error = nil

        // Clear projections when no active session
        if usage.fiveHour == nil {
            projection = nil
        }

        // Track today's peak utilization (survives session resets)
        let today = Calendar.current.startOfDay(for: Date())
        if today != todayPeakDate {
            todayPeakSeen = 0
            todayPeakDate = today
        }
        todayPeakSeen = max(todayPeakSeen, sessionUtilization)

        // Ensure today appears in heatmap and sparkline with live data
        activeDays = injectTodayActivity(into: activeDays)
        dailyPeaks = injectTodayPeak(into: dailyPeaks)

        // Reset notification thresholds when utilization drops
        notificationService.resetThresholds(below: sessionUtilization)

        // Save snapshot and compute projections (only with active session)
        guard dbInitialized, usage.fiveHour != nil else { return }
        Task {
            await saveSnapshotAndProject(usage)
        }
    }

    private func saveSnapshotAndProject(_ usage: UsageResponse) async {
        guard let fiveHour = usage.fiveHour else { return }

        // Save snapshot
        let snapshot = UsageSnapshot(
            sessionUtilization: fiveHour.utilization,
            sessionResetsAt: fiveHour.resetsAtDate ?? Date(),
            weeklyUtilization: usage.sevenDay.utilization,
            weeklyResetsAt: usage.sevenDay.resetsAtDate ?? Date(),
            sonnetUtilization: usage.sevenDaySonnet?.utilization,
            opusUtilization: usage.sevenDayOpus?.utilization,
            planTier: planTier.rawValue
        )

        do {
            try await databaseService.saveSnapshot(snapshot)
        } catch {
            print("Failed to save snapshot: \(error.localizedDescription)")
        }

        // Compute projections from recent snapshots
        do {
            let recentSnapshots = try await databaseService.getLatestSnapshots(count: 20)
            guard let resetsAt = fiveHour.resetsAtDate else { return }

            let proj = BurnRateCalculator.calculate(
                snapshots: recentSnapshots,
                currentUtilization: fiveHour.utilization,
                resetsAt: resetsAt
            )

            await MainActor.run {
                self.projection = proj
            }

            // Check notifications with projection data
            await MainActor.run {
                self.notificationService.checkAndNotify(
                    sessionUtilization: fiveHour.utilization,
                    weeklyUtilization: usage.sevenDay.utilization,
                    projection: proj,
                    sessionResetsAt: fiveHour.resetsAtDate
                )
            }
        } catch {
            print("Failed to compute projections: \(error.localizedDescription)")
        }
    }

    // MARK: - Today Injection

    /// If stats-cache.json hasn't been updated for today yet, inject the day's
    /// peak utilization so the heatmap shows today as active.
    private func injectTodayActivity(into days: [Date: Double]) -> [Date: Double] {
        let today = Calendar.current.startOfDay(for: Date())
        guard days[today] == nil, isConnected, todayPeakSeen > 0 else { return days }
        var merged = days
        merged[today] = todayPeakSeen
        return merged
    }

    /// If stats-cache.json hasn't been updated for today yet, append the day's
    /// peak utilization so the sparkline includes today.
    private func injectTodayPeak(into peaks: [(date: Date, peak: Double)]) -> [(date: Date, peak: Double)] {
        let today = Calendar.current.startOfDay(for: Date())
        guard !peaks.contains(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) else { return peaks }
        guard isConnected, todayPeakSeen > 0 else { return peaks }
        return peaks + [(date: today, peak: todayPeakSeen)]
    }
}
