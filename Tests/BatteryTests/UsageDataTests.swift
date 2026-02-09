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
                "is_enabled": true,
                "monthly_limit": 100.0,
                "used_credits": 4.50,
                "utilization": 4.5
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(UsageResponse.self, from: json)

        XCTAssertEqual(response.fiveHour?.utilization, 45.2)
        XCTAssertEqual(response.sevenDay.utilization, 23.8)
        XCTAssertEqual(response.sevenDaySonnet?.utilization, 12.1)
        XCTAssertEqual(response.sevenDayOpus?.utilization, 67.3)
        XCTAssertEqual(response.extraUsage?.isEnabled, true)
        XCTAssertEqual(response.extraUsage?.usedCredits, 4.50)
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

        XCTAssertEqual(response.fiveHour?.utilization, 10.0)
        XCTAssertNil(response.sevenDaySonnet)
        XCTAssertNil(response.sevenDayOpus)
        XCTAssertNil(response.extraUsage)
    }

    func testDecodeRealAPIResponse() throws {
        // Matches the actual API response format with null fields and extra keys
        let json = """
        {
            "five_hour": {
                "utilization": 100.0,
                "resets_at": "2026-02-06T18:00:00.406306+00:00"
            },
            "seven_day": {
                "utilization": 46.0,
                "resets_at": "2026-02-08T14:00:00.406328+00:00"
            },
            "seven_day_oauth_apps": null,
            "seven_day_opus": null,
            "seven_day_sonnet": {
                "utilization": 6.0,
                "resets_at": "2026-02-10T13:00:00.406334+00:00"
            },
            "seven_day_cowork": null,
            "iguana_necktie": null,
            "extra_usage": {
                "is_enabled": false,
                "monthly_limit": null,
                "used_credits": null,
                "utilization": null
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(UsageResponse.self, from: json)

        XCTAssertEqual(response.fiveHour?.utilization, 100.0)
        XCTAssertEqual(response.sevenDay.utilization, 46.0)
        XCTAssertEqual(response.sevenDaySonnet?.utilization, 6.0)
        XCTAssertNil(response.sevenDayOpus)
        XCTAssertEqual(response.extraUsage?.isEnabled, false)
        XCTAssertNil(response.extraUsage?.usedCredits)
    }

    func testResetsAtDateParsing() {
        let bucket = UsageBucket(utilization: 50.0, resetsAt: "2025-01-15T15:30:00Z")
        let date = bucket.resetsAtDate
        XCTAssertNotNil(date)
    }

    func testResetsAtDateWithFractionalSeconds() {
        let bucket = UsageBucket(utilization: 50.0, resetsAt: "2026-02-06T18:00:00.406306+00:00")
        let date = bucket.resetsAtDate
        XCTAssertNotNil(date)
    }
}
