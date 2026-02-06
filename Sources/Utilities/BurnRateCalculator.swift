import Foundation

/// Calculates burn rate projections from historical snapshots.
/// Phase 2: Full implementation.
struct BurnRateProjection {
    let currentRate: Double           // percentage points per hour
    let projectedLimitTime: Date?     // when 100% will be hit
    let projectedAtReset: Double      // projected utilization at reset time
    let trend: Trend

    enum Trend: String {
        case increasing
        case stable
        case decreasing
    }
}

enum BurnRateCalculator {
    /// Calculate projection from recent snapshots.
    static func calculate(
        snapshots: [UsageSnapshot],
        currentUtilization: Double,
        resetsAt: Date
    ) -> BurnRateProjection {
        // Phase 2: Implement linear regression over snapshots
        // For now, return a stable projection
        return BurnRateProjection(
            currentRate: 0,
            projectedLimitTime: nil,
            projectedAtReset: currentUtilization,
            trend: .stable
        )
    }
}
