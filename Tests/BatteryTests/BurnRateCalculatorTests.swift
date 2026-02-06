import XCTest
@testable import Battery

final class BurnRateCalculatorTests: XCTestCase {

    private func makeSnapshot(
        minutesAgo: Double,
        sessionUtilization: Double,
        resetsAtMinutesFromNow: Double = 120
    ) -> UsageSnapshot {
        UsageSnapshot(
            timestamp: Date().addingTimeInterval(-minutesAgo * 60),
            sessionUtilization: sessionUtilization,
            sessionResetsAt: Date().addingTimeInterval(resetsAtMinutesFromNow * 60),
            weeklyUtilization: 20,
            weeklyResetsAt: Date().addingTimeInterval(86400)
        )
    }

    func testInsufficientData() {
        // Less than 3 snapshots should return stable with no projection
        let snapshots = [
            makeSnapshot(minutesAgo: 10, sessionUtilization: 20),
            makeSnapshot(minutesAgo: 5, sessionUtilization: 25),
        ]
        let result = BurnRateCalculator.calculate(
            snapshots: snapshots,
            currentUtilization: 25,
            resetsAt: Date().addingTimeInterval(3600)
        )

        XCTAssertEqual(result.currentRate, 0)
        XCTAssertNil(result.projectedLimitTime)
        XCTAssertEqual(result.projectedAtReset, 25)
        XCTAssertEqual(result.trend, .stable)
    }

    func testZeroBurnRate() {
        // All snapshots at same utilization = zero rate
        let snapshots = [
            makeSnapshot(minutesAgo: 30, sessionUtilization: 40),
            makeSnapshot(minutesAgo: 20, sessionUtilization: 40),
            makeSnapshot(minutesAgo: 10, sessionUtilization: 40),
            makeSnapshot(minutesAgo: 5, sessionUtilization: 40),
        ]
        let result = BurnRateCalculator.calculate(
            snapshots: snapshots,
            currentUtilization: 40,
            resetsAt: Date().addingTimeInterval(3600)
        )

        XCTAssertEqual(result.currentRate, 0, accuracy: 0.1)
        XCTAssertNil(result.projectedLimitTime)
        XCTAssertEqual(result.projectedAtReset, 40, accuracy: 1.0)
        XCTAssertEqual(result.trend, .stable)
    }

    func testLinearIncreasingRate() {
        // Steady increase: 10% every 10 minutes = 60%/hr
        let snapshots = [
            makeSnapshot(minutesAgo: 30, sessionUtilization: 10),
            makeSnapshot(minutesAgo: 20, sessionUtilization: 20),
            makeSnapshot(minutesAgo: 10, sessionUtilization: 30),
            makeSnapshot(minutesAgo: 0, sessionUtilization: 40),
        ]
        let result = BurnRateCalculator.calculate(
            snapshots: snapshots,
            currentUtilization: 40,
            resetsAt: Date().addingTimeInterval(3600)
        )

        XCTAssertGreaterThan(result.currentRate, 50)  // ~60%/hr
        XCTAssertLessThan(result.currentRate, 70)
        XCTAssertNotNil(result.projectedLimitTime)
        XCTAssertEqual(result.trend, .increasing)

        // Should project hitting 100% in about 1 hour from now
        if let limitTime = result.projectedLimitTime {
            let minutesToLimit = limitTime.timeIntervalSinceNow / 60
            XCTAssertGreaterThan(minutesToLimit, 45)
            XCTAssertLessThan(minutesToLimit, 75)
        }
    }

    func testDecreasingTrend() {
        // Decreasing utilization (e.g., after a reset)
        let snapshots = [
            makeSnapshot(minutesAgo: 30, sessionUtilization: 80),
            makeSnapshot(minutesAgo: 20, sessionUtilization: 60),
            makeSnapshot(minutesAgo: 10, sessionUtilization: 40),
            makeSnapshot(minutesAgo: 0, sessionUtilization: 20),
        ]
        let result = BurnRateCalculator.calculate(
            snapshots: snapshots,
            currentUtilization: 20,
            resetsAt: Date().addingTimeInterval(3600)
        )

        XCTAssertLessThan(result.currentRate, -1.0)
        XCTAssertNil(result.projectedLimitTime)  // Decreasing, won't hit 100%
        XCTAssertEqual(result.trend, .decreasing)
    }

    func testHighBurnRate() {
        // Very fast increase: 20% every 5 minutes = 240%/hr
        let snapshots = [
            makeSnapshot(minutesAgo: 15, sessionUtilization: 20),
            makeSnapshot(minutesAgo: 10, sessionUtilization: 40),
            makeSnapshot(minutesAgo: 5, sessionUtilization: 60),
            makeSnapshot(minutesAgo: 0, sessionUtilization: 80),
        ]
        let result = BurnRateCalculator.calculate(
            snapshots: snapshots,
            currentUtilization: 80,
            resetsAt: Date().addingTimeInterval(3600)
        )

        XCTAssertGreaterThan(result.currentRate, 200)
        XCTAssertNotNil(result.projectedLimitTime)
        XCTAssertEqual(result.trend, .increasing)

        // Should project hitting limit very soon (minutes, not hours)
        if let limitTime = result.projectedLimitTime {
            let minutesToLimit = limitTime.timeIntervalSinceNow / 60
            XCTAssertGreaterThan(minutesToLimit, 0)
            XCTAssertLessThan(minutesToLimit, 10)
        }
    }

    func testProjectedAtResetClamped() {
        // Very high burn rate should clamp projected at reset to 100%
        let snapshots = [
            makeSnapshot(minutesAgo: 15, sessionUtilization: 20),
            makeSnapshot(minutesAgo: 10, sessionUtilization: 40),
            makeSnapshot(minutesAgo: 5, sessionUtilization: 60),
            makeSnapshot(minutesAgo: 0, sessionUtilization: 80),
        ]
        let result = BurnRateCalculator.calculate(
            snapshots: snapshots,
            currentUtilization: 80,
            resetsAt: Date().addingTimeInterval(7200) // 2 hours away
        )

        XCTAssertLessThanOrEqual(result.projectedAtReset, 100)
    }

    func testSnapshotsTooCloseInTime() {
        // All snapshots within 2 minutes should return stable (below minimumTimeSpan)
        let snapshots = [
            makeSnapshot(minutesAgo: 1.5, sessionUtilization: 30),
            makeSnapshot(minutesAgo: 1.0, sessionUtilization: 32),
            makeSnapshot(minutesAgo: 0.5, sessionUtilization: 34),
        ]
        let result = BurnRateCalculator.calculate(
            snapshots: snapshots,
            currentUtilization: 34,
            resetsAt: Date().addingTimeInterval(3600)
        )

        XCTAssertEqual(result.currentRate, 0)
        XCTAssertEqual(result.trend, .stable)
    }
}
