import XCTest
@testable import Battery

final class TimeFormattingTests: XCTestCase {

    func testShortDurationHoursAndMinutes() {
        XCTAssertEqual(TimeFormatting.shortDuration(7980), "2h 13m")  // 2h 13m
    }

    func testShortDurationMinutesOnly() {
        XCTAssertEqual(TimeFormatting.shortDuration(2700), "45m")
    }

    func testShortDurationSeconds() {
        XCTAssertEqual(TimeFormatting.shortDuration(30), "30s")
    }

    func testShortDurationZero() {
        XCTAssertEqual(TimeFormatting.shortDuration(0), "0s")
    }

    func testShortDurationNegative() {
        XCTAssertEqual(TimeFormatting.shortDuration(-10), "0s")
    }

    func testRelativeTimeJustNow() {
        let date = Date().addingTimeInterval(-5)
        XCTAssertEqual(TimeFormatting.relativeTime(date), "just now")
    }

    func testRelativeTimeMinutesAgo() {
        let date = Date().addingTimeInterval(-120)
        XCTAssertEqual(TimeFormatting.relativeTime(date), "2m ago")
    }

    func testRelativeTimeHoursAgo() {
        let date = Date().addingTimeInterval(-3600)
        XCTAssertEqual(TimeFormatting.relativeTime(date), "1h ago")
    }
}
