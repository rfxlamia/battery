import XCTest
@testable import Battery

final class ColorThresholdsTests: XCTestCase {

    func testLowUtilization() {
        XCTAssertEqual(UsageLevel.from(utilization: 0), .low)
        XCTAssertEqual(UsageLevel.from(utilization: 25), .low)
        XCTAssertEqual(UsageLevel.from(utilization: 49.9), .low)
    }

    func testModerateUtilization() {
        XCTAssertEqual(UsageLevel.from(utilization: 50), .moderate)
        XCTAssertEqual(UsageLevel.from(utilization: 65), .moderate)
        XCTAssertEqual(UsageLevel.from(utilization: 74.9), .moderate)
    }

    func testHighUtilization() {
        XCTAssertEqual(UsageLevel.from(utilization: 75), .high)
        XCTAssertEqual(UsageLevel.from(utilization: 85), .high)
        XCTAssertEqual(UsageLevel.from(utilization: 89.9), .high)
    }

    func testCriticalUtilization() {
        XCTAssertEqual(UsageLevel.from(utilization: 90), .critical)
        XCTAssertEqual(UsageLevel.from(utilization: 95), .critical)
        XCTAssertEqual(UsageLevel.from(utilization: 100), .critical)
    }
}
