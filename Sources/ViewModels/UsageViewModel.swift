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

    // MARK: - Services

    private let pollingService = UsagePollingService()
    private let databaseService = DatabaseService()
    private let notificationService = NotificationService()
    private var cancellables = Set<AnyCancellable>()
    private var dbInitialized = false

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
        let pct = Int(sessionUtilization)
        let time = TimeFormatting.shortDuration(sessionTimeRemaining)
        return "\(pct)% · \(time)"
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
    }

    deinit {
        pollingService.stopPolling()
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
                // Load historical chart data
                await loadDailyPeaks()
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
    }

    private func updateFromUsage(_ usage: UsageResponse) {
        sessionUtilization = usage.fiveHour.utilization
        sessionResetsAt = usage.fiveHour.resetsAtDate
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

        // Reset notification thresholds when utilization drops
        notificationService.resetThresholds(below: sessionUtilization)

        // Save snapshot and compute projections
        guard dbInitialized else { return }
        Task {
            await saveSnapshotAndProject(usage)
        }
    }

    private func saveSnapshotAndProject(_ usage: UsageResponse) async {
        // Save snapshot
        let snapshot = UsageSnapshot(
            sessionUtilization: usage.fiveHour.utilization,
            sessionResetsAt: usage.fiveHour.resetsAtDate ?? Date(),
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
            guard let resetsAt = usage.fiveHour.resetsAtDate else { return }

            let proj = BurnRateCalculator.calculate(
                snapshots: recentSnapshots,
                currentUtilization: usage.fiveHour.utilization,
                resetsAt: resetsAt
            )

            await MainActor.run {
                self.projection = proj
            }

            // Check notifications with projection data
            await MainActor.run {
                self.notificationService.checkAndNotify(
                    sessionUtilization: usage.fiveHour.utilization,
                    weeklyUtilization: usage.sevenDay.utilization,
                    projection: proj
                )
            }
        } catch {
            print("Failed to compute projections: \(error.localizedDescription)")
        }

        // Refresh daily peaks for chart
        await loadDailyPeaks()
    }

    private func loadDailyPeaks() async {
        do {
            let peaks = try await databaseService.getDailyPeaks(days: 7)
            await MainActor.run {
                self.dailyPeaks = peaks
            }
        } catch {
            print("Failed to load daily peaks: \(error.localizedDescription)")
        }
    }
}
