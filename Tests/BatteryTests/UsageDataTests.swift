import XCTest
@testable import Battery

final class UsageDataTests: XCTestCase {

    func testDecodeFullResponse() throws {
        let json = """
        {
            "five_hour": {
                "utilization": 45.2,
                "resets_at": "2025-01-15T15:30:00Z"
            },
            "seven_day": {
                "utilization": 23.8,
                "resets_at": "2025-01-20T00:00:00Z"
            },
            "seven_day_sonnet": {
                "utilization": 12.1,
                "resets_at": "2025-01-20T00:00:00Z"
            },
            "seven_day_opus": {
                "utilization": 67.3,
                "resets_at": "2025-01-20T00:00:00Z"
            },
            "extra_usage": {
                "enabled": true,
                "current_period_cost_usd": 4.50
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(UsageResponse.self, from: json)

        XCTAssertEqual(response.fiveHour.utilization, 45.2)
        XCTAssertEqual(response.sevenDay.utilization, 23.8)
        XCTAssertEqual(response.sevenDaySonnet?.utilization, 12.1)
        XCTAssertEqual(response.sevenDayOpus?.utilization, 67.3)
        XCTAssertEqual(response.extraUsage?.enabled, true)
        XCTAssertEqual(response.extraUsage?.currentPeriodCostUsd, 4.50)
    }

    func testDecodeMinimalResponse() throws {
        let json = """
        {
            "five_hour": {
                "utilization": 10.0,
                "resets_at": "2025-01-15T15:30:00Z"
            },
            "seven_day": {
                "utilization": 5.0,
                "resets_at": "2025-01-20T00:00:00Z"
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(UsageResponse.self, from: json)

        XCTAssertEqual(response.fiveHour.utilization, 10.0)
        XCTAssertNil(response.sevenDaySonnet)
        XCTAssertNil(response.sevenDayOpus)
        XCTAssertNil(response.extraUsage)
    }

    func testResetsAtDateParsing() {
        let bucket = UsageBucket(utilization: 50.0, resetsAt: "2025-01-15T15:30:00Z")
        let date = bucket.resetsAtDate
        XCTAssertNotNil(date)
    }
}
