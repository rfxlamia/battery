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
    @Published var isConnected: Bool = false
    @Published var lastUpdated: Date?
    @Published var error: String?
    @Published var planTier: PlanTier = .unknown

    // MARK: - Services

    private let pollingService = UsagePollingService()
    private var cancellables = Set<AnyCancellable>()

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
        extraUsageEnabled = usage.extraUsage?.enabled ?? false
        extraUsageCost = usage.extraUsage?.currentPeriodCostUsd
        isConnected = true
        lastUpdated = Date()
        error = nil
    }
}
