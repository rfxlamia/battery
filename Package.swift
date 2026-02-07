// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Battery",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.3"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "Battery",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources",
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
