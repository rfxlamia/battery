// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Battery",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.3"),
    ],
    targets: [
        .executableTarget(
            name: "Battery",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift"),
            ],
            path: "Sources",
            resources: [
                .copy("../Resources/Assets.xcassets"),
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"]),
            ]
        ),
        .testTarget(
            name: "BatteryTests",
            dependencies: ["Battery"],
            path: "Tests/BatteryTests"
        ),
    ]
)
