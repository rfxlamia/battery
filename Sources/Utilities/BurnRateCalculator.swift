import Foundation

/// Calculates burn rate projections from historical snapshots.
struct BurnRateProjection {
    let currentRate: Double           // percentage points per hour
    let projectedLimitTime: Date?     // when 100% will be hit (nil if rate <= 0 or already at 100%)
    let projectedAtReset: Double      // projected utilization at reset time
    let trend: Trend

    enum Trend: String {
        case increasing
        case stable
        case decreasing
    }
}

enum BurnRateCalculator {

    /// Minimum number of snapshots needed for a meaningful projection.
    static let minimumSnapshots = 3

    /// Minimum time span (seconds) between first and last snapshot for a valid regression.
    static let minimumTimeSpan: TimeInterval = 120 // 2 minutes

    /// Calculate projection from recent snapshots using linear regression.
    ///
    /// - Parameters:
    ///   - snapshots: Recent usage snapshots in chronological order
    ///   - currentUtilization: The most recent utilization percentage (0-100)
    ///   - resetsAt: When the current usage window resets
    /// - Returns: A projection with burn rate, estimated limit time, and trend
    static func calculate(
        snapshots: [UsageSnapshot],
        currentUtilization: Double,
        resetsAt: Date
    ) -> BurnRateProjection {
        guard snapshots.count >= minimumSnapshots else {
            return BurnRateProjection(
                currentRate: 0,
                projectedLimitTime: nil,
                projectedAtReset: currentUtilization,
                trend: .stable
            )
        }

        let sorted = snapshots.sorted { $0.timestamp < $1.timestamp }
        let timeSpan = sorted.last!.timestamp.timeIntervalSince(sorted.first!.timestamp)

        guard timeSpan >= minimumTimeSpan else {
            return BurnRateProjection(
                currentRate: 0,
                projectedLimitTime: nil,
                projectedAtReset: currentUtilization,
                trend: .stable
            )
        }

        // Linear regression: y = mx + b where x = time (hours), y = utilization (%)
        // Use the first snapshot's timestamp as the origin (t=0)
        let origin = sorted.first!.timestamp.timeIntervalSince1970

        let n = Double(sorted.count)
        var sumX: Double = 0
        var sumY: Double = 0
        var sumXY: Double = 0
        var sumX2: Double = 0

        for snapshot in sorted {
            let x = (snapshot.timestamp.timeIntervalSince1970 - origin) / 3600.0  // hours
            let y = snapshot.sessionUtilization
            sumX += x
            sumY += y
            sumXY += x * y
            sumX2 += x * x
        }

        let denominator = n * sumX2 - sumX * sumX
        guard abs(denominator) > 1e-10 else {
            return BurnRateProjection(
                currentRate: 0,
                projectedLimitTime: nil,
                projectedAtReset: currentUtilization,
                trend: .stable
            )
        }

        // Slope = percentage points per hour
        let slope = (n * sumXY - sumX * sumY) / denominator

        // Classify trend
        let trend: BurnRateProjection.Trend
        if slope > 1.0 {
            trend = .increasing
        } else if slope < -1.0 {
            trend = .decreasing
        } else {
            trend = .stable
        }

        // Project when 100% will be hit
        var projectedLimitTime: Date? = nil
        if slope > 0.01 && currentUtilization < 100 {
            let hoursToLimit = (100.0 - currentUtilization) / slope
            projectedLimitTime = Date().addingTimeInterval(hoursToLimit * 3600)
        }

        // Project utilization at reset time
        let hoursToReset = max(0, resetsAt.timeIntervalSinceNow / 3600.0)
        let projectedAtReset = min(100, max(0, currentUtilization + slope * hoursToReset))

        return BurnRateProjection(
            currentRate: slope,
            projectedLimitTime: projectedLimitTime,
            projectedAtReset: projectedAtReset,
            trend: trend
        )
    }
}
