import XCTest
@testable import Battery

final class PlanTierTests: XCTestCase {

    func testFromRateLimitTier() {
        XCTAssertEqual(PlanTier.from(rateLimitTier: "claude_pro"), .pro)
        XCTAssertEqual(PlanTier.from(rateLimitTier: "claude_max"), .max)
        XCTAssertEqual(PlanTier.from(rateLimitTier: "claude_max_5x"), .max5x)
        XCTAssertEqual(PlanTier.from(rateLimitTier: "something_else"), .unknown)
    }

    func testOpusAccess() {
        XCTAssertFalse(PlanTier.pro.hasOpusAccess)
        XCTAssertTrue(PlanTier.max.hasOpusAccess)
        XCTAssertTrue(PlanTier.max5x.hasOpusAccess)
    }
}
