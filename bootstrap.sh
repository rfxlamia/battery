#!/usr/bin/env bash
#
# Battery - Bootstrap Script
# Creates the project structure for a macOS menu bar app that shows Claude Code usage limits.
#
# Usage: ./bootstrap.sh
#

set -euo pipefail

# ─── Colors and Formatting ────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ─── Helper Functions ─────────────────────────────────────────────────────────

info()    { echo -e "${BLUE}[INFO]${RESET}  $1"; }
success() { echo -e "${GREEN}[OK]${RESET}    $1"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $1"; }
error()   { echo -e "${RED}[ERROR]${RESET} $1"; }
step()    { echo -e "\n${BOLD}${MAGENTA}==> $1${RESET}"; }
detail()  { echo -e "    ${DIM}$1${RESET}"; }
file_created() { echo -e "    ${CYAN}+${RESET} $1"; }

# ─── Project Root ─────────────────────────────────────────────────────────────

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

# ─── Banner ───────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}${CYAN}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║          Battery - Bootstrap             ║"
echo "  ║   Claude Code Usage Menu Bar App         ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${RESET}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 1: Prerequisites Check
# ═══════════════════════════════════════════════════════════════════════════════

step "Checking prerequisites..."

# Check Xcode Command Line Tools
if xcode-select -p &>/dev/null; then
    XCODE_PATH=$(xcode-select -p)
    success "Xcode Command Line Tools found: $XCODE_PATH"
else
    error "Xcode Command Line Tools not installed."
    echo "  Install with: xcode-select --install"
    exit 1
fi

# Check Swift version
if command -v swift &>/dev/null; then
    SWIFT_VERSION=$(swift --version 2>&1 | head -1)
    SWIFT_MAJOR=$(swift --version 2>&1 | grep -oE 'Swift version [0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+' | cut -d. -f1)
    SWIFT_MINOR=$(swift --version 2>&1 | grep -oE 'Swift version [0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+' | cut -d. -f2)
    if [[ "$SWIFT_MAJOR" -gt 5 ]] || { [[ "$SWIFT_MAJOR" -eq 5 ]] && [[ "$SWIFT_MINOR" -ge 9 ]]; }; then
        success "Swift version OK: $SWIFT_VERSION"
    else
        error "Swift 5.9+ required. Found: $SWIFT_VERSION"
        exit 1
    fi
else
    error "Swift not found. Install Xcode or Xcode Command Line Tools."
    exit 1
fi

# Check macOS version
MACOS_MAJOR=$(sw_vers -productVersion | cut -d. -f1)
MACOS_MINOR=$(sw_vers -productVersion | cut -d. -f2)
if [[ "$MACOS_MAJOR" -ge 13 ]]; then
    success "macOS version OK: $(sw_vers -productVersion)"
else
    error "macOS 13.0 (Ventura) or later required. Found: $(sw_vers -productVersion)"
    exit 1
fi

# Check Keychain credentials (non-fatal)
KEYCHAIN_CHECK=$(security find-generic-password -s "Claude Code-credentials" 2>&1 || true)
if echo "$KEYCHAIN_CHECK" | grep -q "could not be found"; then
    warn "Claude Code credentials not found in Keychain."
    detail "The app will show an error state until you sign in to Claude Code."
    detail "Run 'claude' in terminal and sign in to populate credentials."
else
    success "Claude Code credentials found in Keychain"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 2: Create Directory Structure
# ═══════════════════════════════════════════════════════════════════════════════

step "Creating directory structure..."

DIRS=(
    "Sources"
    "Sources/Views"
    "Sources/Views/Components"
    "Sources/ViewModels"
    "Sources/Models"
    "Sources/Services"
    "Sources/Utilities"
    "Resources/Assets.xcassets/AppIcon.appiconset"
    "Hooks"
    "Scripts"
    "Tests/BatteryTests"
)

for dir in "${DIRS[@]}"; do
    mkdir -p "$PROJECT_DIR/$dir"
done

success "Directory structure created (${#DIRS[@]} directories)"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 3: Generate Package.swift
# ═══════════════════════════════════════════════════════════════════════════════

step "Generating Package.swift..."

cat > "$PROJECT_DIR/Package.swift" << 'PACKAGE_EOF'
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
PACKAGE_EOF

file_created "Package.swift"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 4: Generate Info.plist
# ═══════════════════════════════════════════════════════════════════════════════

step "Generating Info.plist and entitlements..."

cat > "$PROJECT_DIR/Info.plist" << 'PLIST_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Battery</string>
    <key>CFBundleDisplayName</key>
    <string>Battery</string>
    <key>CFBundleIdentifier</key>
    <string>com.allthingsclaude.battery</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>Battery</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright 2025 All Things Claude</string>
</dict>
</plist>
PLIST_EOF

file_created "Info.plist"

cat > "$PROJECT_DIR/Battery.entitlements" << 'ENTITLEMENTS_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)com.allthingsclaude.battery</string>
    </array>
</dict>
</plist>
ENTITLEMENTS_EOF

file_created "Battery.entitlements"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 5: Generate Swift Source Files
# ═══════════════════════════════════════════════════════════════════════════════

step "Generating Swift source files..."

# ─── BatteryApp.swift (Entry Point) ──────────────────────────────────────────

cat > "$PROJECT_DIR/Sources/BatteryApp.swift" << 'SWIFT_EOF'
import SwiftUI

@main
struct BatteryApp: App {
    @StateObject private var viewModel = UsageViewModel()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(viewModel: viewModel)
                .frame(width: 320)
        } label: {
            MenuBarIconView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}
SWIFT_EOF

file_created "Sources/BatteryApp.swift"

# ─── Models ──────────────────────────────────────────────────────────────────

cat > "$PROJECT_DIR/Sources/Models/UsageData.swift" << 'SWIFT_EOF'
import Foundation

// MARK: - API Response Models

struct UsageResponse: Codable {
    let fiveHour: UsageBucket
    let sevenDay: UsageBucket
    let sevenDaySonnet: UsageBucket?
    let sevenDayOpus: UsageBucket?
    let extraUsage: ExtraUsage?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDaySonnet = "seven_day_sonnet"
        case sevenDayOpus = "seven_day_opus"
        case extraUsage = "extra_usage"
    }
}

struct UsageBucket: Codable {
    let utilization: Double
    let resetsAt: String

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }

    /// Parse the ISO 8601 reset time into a Date
    var resetsAtDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: resetsAt) {
            return date
        }
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: resetsAt)
    }
}

struct ExtraUsage: Codable {
    let enabled: Bool
    let currentPeriodCostUsd: Double?

    enum CodingKeys: String, CodingKey {
        case enabled
        case currentPeriodCostUsd = "current_period_cost_usd"
    }
}
SWIFT_EOF

file_created "Sources/Models/UsageData.swift"

cat > "$PROJECT_DIR/Sources/Models/UsageSnapshot.swift" << 'SWIFT_EOF'
import Foundation

/// A point-in-time record of usage data, stored in SQLite for historical tracking.
struct UsageSnapshot: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let sessionUtilization: Double
    let sessionResetsAt: Date
    let weeklyUtilization: Double
    let weeklyResetsAt: Date
    let sonnetUtilization: Double?
    let opusUtilization: Double?
    let planTier: String

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        sessionUtilization: Double,
        sessionResetsAt: Date,
        weeklyUtilization: Double,
        weeklyResetsAt: Date,
        sonnetUtilization: Double? = nil,
        opusUtilization: Double? = nil,
        planTier: String = "unknown"
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sessionUtilization = sessionUtilization
        self.sessionResetsAt = sessionResetsAt
        self.weeklyUtilization = weeklyUtilization
        self.weeklyResetsAt = weeklyResetsAt
        self.sonnetUtilization = sonnetUtilization
        self.opusUtilization = opusUtilization
        self.planTier = planTier
    }
}
SWIFT_EOF

file_created "Sources/Models/UsageSnapshot.swift"

cat > "$PROJECT_DIR/Sources/Models/SessionEvent.swift" << 'SWIFT_EOF'
import Foundation

/// Events written by the Claude Code hook script.
struct SessionEvent: Codable {
    let event: EventType
    let timestamp: Date
    let sessionId: String?
    let tool: String?

    enum EventType: String, Codable {
        case sessionStart = "SessionStart"
        case sessionEnd = "SessionEnd"
        case postToolUse = "PostToolUse"
        case stop = "Stop"
    }

    enum CodingKeys: String, CodingKey {
        case event
        case timestamp
        case sessionId = "session_id"
        case tool
    }
}
SWIFT_EOF

file_created "Sources/Models/SessionEvent.swift"

cat > "$PROJECT_DIR/Sources/Models/AppSettings.swift" << 'SWIFT_EOF'
import SwiftUI

/// App settings backed by UserDefaults via @AppStorage.
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("notifyAt80") var notifyAt80: Bool = true
    @AppStorage("notifyAt90") var notifyAt90: Bool = true
    @AppStorage("notifyAt95") var notifyAt95: Bool = true
    @AppStorage("showMenuBarText") var showMenuBarText: Bool = true
    @AppStorage("menuBarDisplayMode") var menuBarDisplayMode: String = "percentageAndTime"
    @AppStorage("pollIntervalActive") var pollIntervalActive: Double = 30
    @AppStorage("pollIntervalIdle") var pollIntervalIdle: Double = 300
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("dataRetentionDays") var dataRetentionDays: Int = 90
}
SWIFT_EOF

file_created "Sources/Models/AppSettings.swift"

cat > "$PROJECT_DIR/Sources/Models/PlanTier.swift" << 'SWIFT_EOF'
import Foundation

/// Claude subscription plan tiers detected from Keychain credentials.
enum PlanTier: String, Codable, CaseIterable {
    case pro = "pro"
    case max = "max"
    case max5x = "max_5x"
    case unknown = "unknown"

    var displayName: String {
        switch self {
        case .pro: return "Pro"
        case .max: return "Max"
        case .max5x: return "Max 5x"
        case .unknown: return "Unknown"
        }
    }

    var hasOpusAccess: Bool {
        switch self {
        case .max, .max5x: return true
        case .pro, .unknown: return false
        }
    }

    var hasSonnetTracking: Bool {
        return true // All plans have Sonnet tracking
    }

    /// Map the rateLimitTier string from Keychain to a PlanTier.
    static func from(rateLimitTier: String) -> PlanTier {
        switch rateLimitTier.lowercased() {
        case let t where t.contains("max_5x") || t.contains("max5x"):
            return .max5x
        case let t where t.contains("max"):
            return .max
        case let t where t.contains("pro"):
            return .pro
        default:
            return .unknown
        }
    }
}
SWIFT_EOF

file_created "Sources/Models/PlanTier.swift"

# ─── Services ────────────────────────────────────────────────────────────────

cat > "$PROJECT_DIR/Sources/Services/KeychainService.swift" << 'SWIFT_EOF'
import Foundation
import Security

/// Reads Claude Code OAuth credentials from the macOS Keychain.
actor KeychainService {

    struct Credentials {
        let accessToken: String
        let refreshToken: String
        let expiresAt: Date
        let subscriptionType: String
        let rateLimitTier: String
    }

    enum KeychainError: LocalizedError {
        case itemNotFound
        case unexpectedData
        case jsonParsingFailed(String)
        case missingField(String)
        case osError(OSStatus)

        var errorDescription: String? {
            switch self {
            case .itemNotFound:
                return "Claude Code credentials not found in Keychain. Sign in with 'claude' first."
            case .unexpectedData:
                return "Keychain item data could not be read."
            case .jsonParsingFailed(let detail):
                return "Failed to parse Keychain JSON: \(detail)"
            case .missingField(let field):
                return "Missing field in credentials: \(field)"
            case .osError(let status):
                return "Keychain error: \(status)"
            }
        }
    }

    func readCredentials() throws -> Credentials {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.osError(status)
        }

        guard let data = result as? Data else {
            throw KeychainError.unexpectedData
        }

        return try parseCredentials(data)
    }

    private func parseCredentials(_ data: Data) throws -> Credentials {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw KeychainError.jsonParsingFailed("Root object is not a dictionary")
        }

        guard let oauth = json["claudeAiOauth"] as? [String: Any] else {
            throw KeychainError.missingField("claudeAiOauth")
        }

        guard let accessToken = oauth["accessToken"] as? String else {
            throw KeychainError.missingField("accessToken")
        }

        guard let refreshToken = oauth["refreshToken"] as? String else {
            throw KeychainError.missingField("refreshToken")
        }

        guard let expiresAtMs = oauth["expiresAt"] as? Double else {
            throw KeychainError.missingField("expiresAt")
        }

        let subscriptionType = oauth["subscriptionType"] as? String ?? "unknown"
        let rateLimitTier = oauth["rateLimitTier"] as? String ?? "unknown"

        let expiresAt = Date(timeIntervalSince1970: expiresAtMs / 1000.0)

        return Credentials(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            subscriptionType: subscriptionType,
            rateLimitTier: rateLimitTier
        )
    }
}
SWIFT_EOF

file_created "Sources/Services/KeychainService.swift"

cat > "$PROJECT_DIR/Sources/Services/TokenRefreshService.swift" << 'SWIFT_EOF'
import Foundation

/// Handles OAuth token refresh when the access token is near expiry.
actor TokenRefreshService {

    struct TokenResponse: Codable {
        let accessToken: String
        let tokenType: String
        let expiresIn: Int
        let refreshToken: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case tokenType = "token_type"
            case expiresIn = "expires_in"
            case refreshToken = "refresh_token"
        }
    }

    enum TokenError: LocalizedError {
        case refreshFailed(statusCode: Int, body: String)
        case networkError(Error)

        var errorDescription: String? {
            switch self {
            case .refreshFailed(let code, let body):
                return "Token refresh failed (HTTP \(code)): \(body)"
            case .networkError(let error):
                return "Network error during token refresh: \(error.localizedDescription)"
            }
        }
    }

    private let refreshBufferSeconds: TimeInterval = 300 // 5 minutes

    /// Returns a valid access token, refreshing if needed.
    func refreshIfNeeded(credentials: KeychainService.Credentials) async throws -> String {
        if credentials.expiresAt.timeIntervalSinceNow > refreshBufferSeconds {
            return credentials.accessToken
        }
        let response = try await forceRefresh(refreshToken: credentials.refreshToken)
        // TODO: Update Keychain with new tokens
        return response.accessToken
    }

    /// Force a token refresh using the refresh token.
    func forceRefresh(refreshToken: String) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: Constants.tokenRefreshURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "grant_type=refresh_token&refresh_token=\(refreshToken)"
        request.httpBody = body.data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TokenError.refreshFailed(statusCode: 0, body: "Invalid response")
            }

            guard httpResponse.statusCode == 200 else {
                let body = String(data: data, encoding: .utf8) ?? "No body"
                throw TokenError.refreshFailed(statusCode: httpResponse.statusCode, body: body)
            }

            return try JSONDecoder().decode(TokenResponse.self, from: data)
        } catch let error as TokenError {
            throw error
        } catch {
            throw TokenError.networkError(error)
        }
    }
}
SWIFT_EOF

file_created "Sources/Services/TokenRefreshService.swift"

cat > "$PROJECT_DIR/Sources/Services/AnthropicAPI.swift" << 'SWIFT_EOF'
import Foundation

/// Client for the Anthropic OAuth usage API.
actor AnthropicAPI {

    enum APIError: LocalizedError {
        case unauthorized
        case rateLimited(retryAfter: TimeInterval?)
        case serverError(statusCode: Int, body: String)
        case networkError(Error)
        case decodingError(Error)

        var errorDescription: String? {
            switch self {
            case .unauthorized:
                return "Unauthorized (401). Token may be expired."
            case .rateLimited(let retryAfter):
                if let seconds = retryAfter {
                    return "Rate limited. Retry after \(Int(seconds))s."
                }
                return "Rate limited."
            case .serverError(let code, let body):
                return "Server error (\(code)): \(body)"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .decodingError(let error):
                return "Failed to decode response: \(error.localizedDescription)"
            }
        }

        var isUnauthorized: Bool {
            if case .unauthorized = self { return true }
            return false
        }
    }

    /// Fetch current usage data from the Anthropic API.
    func fetchUsage(accessToken: String) async throws -> UsageResponse {
        var request = URLRequest(url: URL(string: "\(Constants.apiBaseURL)/api/oauth/usage")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(Constants.betaHeader, forHTTPHeaderField: "anthropic-beta")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.serverError(statusCode: 0, body: "Invalid response")
            }

            switch httpResponse.statusCode {
            case 200:
                break
            case 401:
                throw APIError.unauthorized
            case 429:
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                    .flatMap { TimeInterval($0) }
                throw APIError.rateLimited(retryAfter: retryAfter)
            default:
                let body = String(data: data, encoding: .utf8) ?? "No body"
                throw APIError.serverError(statusCode: httpResponse.statusCode, body: body)
            }

            do {
                return try JSONDecoder().decode(UsageResponse.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
}
SWIFT_EOF

file_created "Sources/Services/AnthropicAPI.swift"

cat > "$PROJECT_DIR/Sources/Services/UsagePollingService.swift" << 'SWIFT_EOF'
import Foundation
import Combine

/// Coordinates periodic polling of the Anthropic usage API.
class UsagePollingService: ObservableObject {
    @Published var latestUsage: UsageResponse?
    @Published var lastError: Error?
    @Published var isPolling: Bool = false

    private let keychainService = KeychainService()
    private let tokenRefreshService = TokenRefreshService()
    private let api = AnthropicAPI()
    private var pollingTask: Task<Void, Never>?
    private var currentInterval: TimeInterval

    init(interval: TimeInterval = Constants.defaultPollInterval) {
        self.currentInterval = interval
    }

    func startPolling() {
        guard !isPolling else { return }
        isPolling = true
        pollingTask = Task { [weak self] in
            guard let self = self else { return }
            // Immediate first poll
            await self.pollNow()
            // Then poll at interval
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self.currentInterval * 1_000_000_000))
                if Task.isCancelled { break }
                await self.pollNow()
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        isPolling = false
    }

    func setInterval(_ interval: TimeInterval) {
        currentInterval = interval
    }

    @MainActor
    func pollNow() async {
        do {
            let credentials = try await keychainService.readCredentials()
            let token = try await tokenRefreshService.refreshIfNeeded(credentials: credentials)
            let usage = try await api.fetchUsage(accessToken: token)
            self.latestUsage = usage
            self.lastError = nil
        } catch {
            self.lastError = error
            // On 401, try once more with forced refresh
            if let apiError = error as? AnthropicAPI.APIError, apiError.isUnauthorized {
                await retryWithRefresh()
            }
        }
    }

    @MainActor
    private func retryWithRefresh() async {
        do {
            let credentials = try await keychainService.readCredentials()
            let tokenResponse = try await tokenRefreshService.forceRefresh(refreshToken: credentials.refreshToken)
            let usage = try await api.fetchUsage(accessToken: tokenResponse.accessToken)
            self.latestUsage = usage
            self.lastError = nil
        } catch {
            self.lastError = error
        }
    }
}
SWIFT_EOF

file_created "Sources/Services/UsagePollingService.swift"

cat > "$PROJECT_DIR/Sources/Services/DatabaseService.swift" << 'SWIFT_EOF'
import Foundation
import SQLite

/// SQLite-backed persistence for usage history snapshots.
/// Phase 2: Full implementation with schema, CRUD, and pruning.
actor DatabaseService {

    private var db: Connection?

    // Table definition
    private let snapshots = Table("usage_snapshots")
    private let colId = SQLite.Expression<String>("id")
    private let colTimestamp = SQLite.Expression<Double>("timestamp")
    private let colSessionUtil = SQLite.Expression<Double>("session_utilization")
    private let colSessionResets = SQLite.Expression<Double>("session_resets_at")
    private let colWeeklyUtil = SQLite.Expression<Double>("weekly_utilization")
    private let colWeeklyResets = SQLite.Expression<Double>("weekly_resets_at")
    private let colSonnetUtil = SQLite.Expression<Double?>("sonnet_utilization")
    private let colOpusUtil = SQLite.Expression<Double?>("opus_utilization")
    private let colPlanTier = SQLite.Expression<String>("plan_tier")

    func initialize() throws {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let batteryDir = appSupport.appendingPathComponent("Battery", isDirectory: true)
        try FileManager.default.createDirectory(at: batteryDir, withIntermediateDirectories: true)
        let dbPath = batteryDir.appendingPathComponent("battery.db").path
        db = try Connection(dbPath)

        try db?.run(snapshots.create(ifNotExists: true) { t in
            t.column(colId, primaryKey: true)
            t.column(colTimestamp)
            t.column(colSessionUtil)
            t.column(colSessionResets)
            t.column(colWeeklyUtil)
            t.column(colWeeklyResets)
            t.column(colSonnetUtil)
            t.column(colOpusUtil)
            t.column(colPlanTier)
        })

        // Create index on timestamp for efficient range queries
        try db?.run(snapshots.createIndex(colTimestamp, ifNotExists: true))
    }

    func saveSnapshot(_ snapshot: UsageSnapshot) throws {
        guard let db = db else { return }
        try db.run(snapshots.insert(
            colId <- snapshot.id.uuidString,
            colTimestamp <- snapshot.timestamp.timeIntervalSince1970,
            colSessionUtil <- snapshot.sessionUtilization,
            colSessionResets <- snapshot.sessionResetsAt.timeIntervalSince1970,
            colWeeklyUtil <- snapshot.weeklyUtilization,
            colWeeklyResets <- snapshot.weeklyResetsAt.timeIntervalSince1970,
            colSonnetUtil <- snapshot.sonnetUtilization,
            colOpusUtil <- snapshot.opusUtilization,
            colPlanTier <- snapshot.planTier
        ))
    }

    func pruneOldData(olderThan date: Date) throws {
        guard let db = db else { return }
        let old = snapshots.filter(colTimestamp < date.timeIntervalSince1970)
        try db.run(old.delete())
    }
}
SWIFT_EOF

file_created "Sources/Services/DatabaseService.swift"

cat > "$PROJECT_DIR/Sources/Services/NotificationService.swift" << 'SWIFT_EOF'
import Foundation
import UserNotifications

/// Manages macOS native notifications for usage threshold alerts.
class NotificationService {
    private var notifiedThresholds: Set<Int> = []

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    func checkAndNotify(sessionUtilization: Double, weeklyUtilization: Double) {
        let thresholds = [80, 90, 95]
        for threshold in thresholds {
            if sessionUtilization >= Double(threshold) && !notifiedThresholds.contains(threshold) {
                sendNotification(
                    title: "Session Usage at \(threshold)%",
                    body: "Your 5-hour Claude Code session is at \(Int(sessionUtilization))% utilization."
                )
                notifiedThresholds.insert(threshold)
            }
        }
    }

    func resetThresholds(below utilization: Double) {
        notifiedThresholds = notifiedThresholds.filter { Double($0) <= utilization }
    }

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
SWIFT_EOF

file_created "Sources/Services/NotificationService.swift"

cat > "$PROJECT_DIR/Sources/Services/HookFileWatcher.swift" << 'SWIFT_EOF'
import Foundation
import Combine

/// Watches the hook events file for Claude Code session activity.
/// Phase 3: Full implementation.
class HookFileWatcher: ObservableObject {
    @Published var isSessionActive: Bool = false
    @Published var lastActivity: Date?
    @Published var currentSessionStart: Date?

    private let eventsFilePath: String
    private var fileHandle: FileHandle?
    private var source: DispatchSourceFileSystemObject?

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.eventsFilePath = home.appendingPathComponent(".battery/events.jsonl").path
    }

    func startWatching() {
        // Phase 3: Implement DispatchSource file watcher
        // For now, this is a stub
    }

    func stopWatching() {
        source?.cancel()
        source = nil
        fileHandle?.closeFile()
        fileHandle = nil
    }
}
SWIFT_EOF

file_created "Sources/Services/HookFileWatcher.swift"

# ─── ViewModels ──────────────────────────────────────────────────────────────

cat > "$PROJECT_DIR/Sources/ViewModels/UsageViewModel.swift" << 'SWIFT_EOF'
import SwiftUI
import Combine

/// Main view model that coordinates all services and provides state to views.
class UsageViewModel: ObservableObject {
    // MARK: - Published State

    @Published var sessionUtilization: Double = 0
    @Published var sessionResetsAt: Date?
    @Published var weeklyUtilization: Double = 0
    @Published var weeklyResetsAt: Date?
    @Published var sonnetUtilization: Double?
    @Published var opusUtilization: Double?
    @Published var extraUsageEnabled: Bool = false
    @Published var extraUsageCost: Double?
    @Published var isConnected: Bool = false
    @Published var lastUpdated: Date?
    @Published var error: String?
    @Published var planTier: PlanTier = .unknown

    // MARK: - Services

    private let pollingService = UsagePollingService()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    var sessionTimeRemaining: TimeInterval {
        guard let resetsAt = sessionResetsAt else { return 0 }
        return max(0, resetsAt.timeIntervalSinceNow)
    }

    var weeklyTimeRemaining: TimeInterval {
        guard let resetsAt = weeklyResetsAt else { return 0 }
        return max(0, resetsAt.timeIntervalSinceNow)
    }

    var sessionColor: Color {
        UsageLevel.from(utilization: sessionUtilization).color
    }

    var weeklyColor: Color {
        UsageLevel.from(utilization: weeklyUtilization).color
    }

    var menuBarText: String {
        let pct = Int(sessionUtilization)
        let time = TimeFormatting.shortDuration(sessionTimeRemaining)
        return "\(pct)% · \(time)"
    }

    var menuBarSymbol: String {
        UsageLevel.from(utilization: sessionUtilization).sfSymbol
    }

    // MARK: - Lifecycle

    init() {
        setupBindings()
        pollingService.startPolling()
    }

    deinit {
        pollingService.stopPolling()
    }

    func refresh() {
        Task {
            await pollingService.pollNow()
        }
    }

    // MARK: - Private

    private func setupBindings() {
        pollingService.$latestUsage
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] usage in
                self?.updateFromUsage(usage)
            }
            .store(in: &cancellables)

        pollingService.$lastError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.error = error?.localizedDescription
                if error != nil {
                    self?.isConnected = false
                }
            }
            .store(in: &cancellables)
    }

    private func updateFromUsage(_ usage: UsageResponse) {
        sessionUtilization = usage.fiveHour.utilization
        sessionResetsAt = usage.fiveHour.resetsAtDate
        weeklyUtilization = usage.sevenDay.utilization
        weeklyResetsAt = usage.sevenDay.resetsAtDate
        sonnetUtilization = usage.sevenDaySonnet?.utilization
        opusUtilization = usage.sevenDayOpus?.utilization
        extraUsageEnabled = usage.extraUsage?.enabled ?? false
        extraUsageCost = usage.extraUsage?.currentPeriodCostUsd
        isConnected = true
        lastUpdated = Date()
        error = nil
    }
}
SWIFT_EOF

file_created "Sources/ViewModels/UsageViewModel.swift"

cat > "$PROJECT_DIR/Sources/ViewModels/SettingsViewModel.swift" << 'SWIFT_EOF'
import SwiftUI

/// View model for the settings panel.
/// Phase 3: Full implementation.
class SettingsViewModel: ObservableObject {
    @Published var settings = AppSettings.shared
}
SWIFT_EOF

file_created "Sources/ViewModels/SettingsViewModel.swift"

# ─── Views ───────────────────────────────────────────────────────────────────

cat > "$PROJECT_DIR/Sources/Views/MenuBarIconView.swift" << 'SWIFT_EOF'
import SwiftUI

/// The label displayed in the macOS menu bar.
struct MenuBarIconView: View {
    @ObservedObject var viewModel: UsageViewModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: viewModel.menuBarSymbol)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(viewModel.sessionColor)

            if viewModel.isConnected {
                Text(viewModel.menuBarText)
                    .font(.caption)
                    .monospacedDigit()
            } else {
                Text("--")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
SWIFT_EOF

file_created "Sources/Views/MenuBarIconView.swift"

cat > "$PROJECT_DIR/Sources/Views/PopoverView.swift" << 'SWIFT_EOF'
import SwiftUI

/// Main popover panel shown when clicking the menu bar icon.
struct PopoverView: View {
    @ObservedObject var viewModel: UsageViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Battery")
                    .font(.headline)
                Spacer()
                if let tier = Optional(viewModel.planTier), tier != .unknown {
                    Text(tier.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .clipShape(Capsule())
                }
            }
            .padding(.bottom, 4)

            if let error = viewModel.error {
                // Error state
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                // Session gauge (5-hour)
                SessionGaugeView(
                    title: "Session (5-hour)",
                    utilization: viewModel.sessionUtilization,
                    resetsAt: viewModel.sessionResetsAt,
                    color: viewModel.sessionColor
                )

                Divider()

                // Weekly gauge (7-day)
                WeeklyGaugeView(
                    title: "Weekly (7-day)",
                    utilization: viewModel.weeklyUtilization,
                    resetsAt: viewModel.weeklyResetsAt,
                    color: viewModel.weeklyColor
                )

                // Opus gauge (if applicable)
                if let opusUtil = viewModel.opusUtilization {
                    Divider()
                    WeeklyGaugeView(
                        title: "Opus (7-day)",
                        utilization: opusUtil,
                        resetsAt: viewModel.weeklyResetsAt,
                        color: UsageLevel.from(utilization: opusUtil).color
                    )
                }
            }

            Divider()

            // Footer
            HStack {
                if let lastUpdated = viewModel.lastUpdated {
                    Text("Updated \(TimeFormatting.relativeTime(lastUpdated))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button(action: { viewModel.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)

                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Text("Quit")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
    }
}
SWIFT_EOF

file_created "Sources/Views/PopoverView.swift"

cat > "$PROJECT_DIR/Sources/Views/SessionGaugeView.swift" << 'SWIFT_EOF'
import SwiftUI

/// Displays the 5-hour session usage with a circular gauge and countdown.
struct SessionGaugeView: View {
    let title: String
    let utilization: Double
    let resetsAt: Date?
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            // Circular gauge
            GaugeRingView(
                value: utilization / 100.0,
                color: color,
                size: 56
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(Int(utilization))%")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
                    .monospacedDigit()

                if let resetsAt = resetsAt {
                    CountdownLabel(targetDate: resetsAt)
                }
            }

            Spacer()
        }
    }
}
SWIFT_EOF

file_created "Sources/Views/SessionGaugeView.swift"

cat > "$PROJECT_DIR/Sources/Views/WeeklyGaugeView.swift" << 'SWIFT_EOF'
import SwiftUI

/// Displays the weekly usage with a compact horizontal bar.
struct WeeklyGaugeView: View {
    let title: String
    let utilization: Double
    let resetsAt: Date?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(utilization))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(color)
                    .monospacedDigit()
            }

            // Horizontal progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.quaternary)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geometry.size.width * min(utilization / 100.0, 1.0), height: 6)
                        .animation(.easeInOut(duration: 0.5), value: utilization)
                }
            }
            .frame(height: 6)

            if let resetsAt = resetsAt {
                HStack {
                    Text("Resets in")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    CountdownLabel(targetDate: resetsAt, style: .compact)
                }
            }
        }
    }
}
SWIFT_EOF

file_created "Sources/Views/WeeklyGaugeView.swift"

cat > "$PROJECT_DIR/Sources/Views/ProjectionView.swift" << 'SWIFT_EOF'
import SwiftUI

/// Displays burn rate projections. Phase 2 implementation.
struct ProjectionView: View {
    var body: some View {
        // Phase 2: Burn rate projections
        Text("Projections coming soon")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
SWIFT_EOF

file_created "Sources/Views/ProjectionView.swift"

cat > "$PROJECT_DIR/Sources/Views/StatsView.swift" << 'SWIFT_EOF'
import SwiftUI

/// Historical charts and streak tracking. Phase 2/3 implementation.
struct StatsView: View {
    var body: some View {
        // Phase 2/3: Charts, streaks, daily stats
        Text("Stats coming soon")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
SWIFT_EOF

file_created "Sources/Views/StatsView.swift"

cat > "$PROJECT_DIR/Sources/Views/SettingsView.swift" << 'SWIFT_EOF'
import SwiftUI

/// App settings panel. Phase 3 implementation.
struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        // Phase 3: Full settings panel
        Form {
            Section("Notifications") {
                Toggle("Notify at 80%", isOn: $settings.notifyAt80)
                Toggle("Notify at 90%", isOn: $settings.notifyAt90)
                Toggle("Notify at 95%", isOn: $settings.notifyAt95)
            }
        }
        .padding()
        .frame(width: 300)
    }
}
SWIFT_EOF

file_created "Sources/Views/SettingsView.swift"

# ─── View Components ─────────────────────────────────────────────────────────

cat > "$PROJECT_DIR/Sources/Views/Components/GaugeRingView.swift" << 'SWIFT_EOF'
import SwiftUI

/// A circular arc gauge that fills based on a 0-1 value.
struct GaugeRingView: View {
    let value: Double  // 0.0 to 1.0
    let color: Color
    let size: CGFloat
    let lineWidth: CGFloat

    init(value: Double, color: Color, size: CGFloat = 60, lineWidth: CGFloat = 6) {
        self.value = min(max(value, 0), 1)
        self.color = color
        self.size = size
        self.lineWidth = lineWidth
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(.quaternary, lineWidth: lineWidth)

            // Filled arc
            Circle()
                .trim(from: 0, to: value)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: value)

            // Center percentage
            Text("\(Int(value * 100))")
                .font(.system(size: size * 0.28, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
    }
}
SWIFT_EOF

file_created "Sources/Views/Components/GaugeRingView.swift"

cat > "$PROJECT_DIR/Sources/Views/Components/CountdownLabel.swift" << 'SWIFT_EOF'
import SwiftUI

/// Displays a live countdown to a target date, updating every second.
struct CountdownLabel: View {
    let targetDate: Date
    var style: CountdownStyle = .full

    enum CountdownStyle {
        case full     // "2h 13m remaining"
        case compact  // "2h 13m"
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = targetDate.timeIntervalSince(context.date)
            if remaining > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(formattedTime(remaining))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    if style == .full {
                        Text("remaining")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            } else {
                Text("Resetting...")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }

    private func formattedTime(_ interval: TimeInterval) -> String {
        TimeFormatting.shortDuration(interval)
    }
}
SWIFT_EOF

file_created "Sources/Views/Components/CountdownLabel.swift"

cat > "$PROJECT_DIR/Sources/Views/Components/StatusDot.swift" << 'SWIFT_EOF'
import SwiftUI

/// A small color-coded status indicator dot.
struct StatusDot: View {
    let color: Color
    let size: CGFloat

    init(color: Color, size: CGFloat = 8) {
        self.color = color
        self.size = size
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
    }
}
SWIFT_EOF

file_created "Sources/Views/Components/StatusDot.swift"

# ─── Utilities ───────────────────────────────────────────────────────────────

cat > "$PROJECT_DIR/Sources/Utilities/TimeFormatting.swift" << 'SWIFT_EOF'
import Foundation

/// Helpers for formatting durations and relative times.
enum TimeFormatting {

    /// Format a time interval as a short duration string.
    /// Examples: "2h 13m", "45m", "30s", "< 1m"
    static func shortDuration(_ interval: TimeInterval) -> String {
        guard interval > 0 else { return "0s" }

        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else if seconds > 0 {
            return "\(seconds)s"
        } else {
            return "< 1m"
        }
    }

    /// Format a date as a relative time string.
    /// Examples: "just now", "2m ago", "1h ago"
    static func relativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)

        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}
SWIFT_EOF

file_created "Sources/Utilities/TimeFormatting.swift"

cat > "$PROJECT_DIR/Sources/Utilities/ColorThresholds.swift" << 'SWIFT_EOF'
import SwiftUI

/// Maps utilization percentages to color-coded severity levels.
enum UsageLevel: String, CaseIterable {
    case low       // 0-50%  green
    case moderate  // 50-75% yellow
    case high      // 75-90% orange
    case critical  // 90%+   red

    static func from(utilization: Double) -> UsageLevel {
        switch utilization {
        case ..<50:
            return .low
        case 50..<75:
            return .moderate
        case 75..<90:
            return .high
        default:
            return .critical
        }
    }

    var color: Color {
        switch self {
        case .low:      return .green
        case .moderate: return .yellow
        case .high:     return .orange
        case .critical: return .red
        }
    }

    var sfSymbol: String {
        switch self {
        case .low:      return "battery.75percent"
        case .moderate: return "battery.50percent"
        case .high:     return "battery.25percent"
        case .critical: return "battery.25percent"
        }
    }

    var label: String {
        switch self {
        case .low:      return "Good"
        case .moderate: return "Moderate"
        case .high:     return "High"
        case .critical: return "Critical"
        }
    }
}
SWIFT_EOF

file_created "Sources/Utilities/ColorThresholds.swift"

cat > "$PROJECT_DIR/Sources/Utilities/BurnRateCalculator.swift" << 'SWIFT_EOF'
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
SWIFT_EOF

file_created "Sources/Utilities/BurnRateCalculator.swift"

cat > "$PROJECT_DIR/Sources/Utilities/Constants.swift" << 'SWIFT_EOF'
import Foundation

/// App-wide constants.
enum Constants {
    static let apiBaseURL = "https://api.anthropic.com"
    static let tokenRefreshURL = "https://platform.claude.com/v1/oauth/token"
    static let keychainService = "Claude Code-credentials"
    static let betaHeader = "oauth-2025-04-20"

    // Polling intervals (seconds)
    static let defaultPollInterval: TimeInterval = 60
    static let activePollInterval: TimeInterval = 30
    static let idlePollInterval: TimeInterval = 300

    // Notification thresholds
    static let defaultThresholds: [Int] = [80, 90, 95]

    // Database
    static let dataRetentionDays: Int = 90
}
SWIFT_EOF

file_created "Sources/Utilities/Constants.swift"

# ─── Tests ───────────────────────────────────────────────────────────────────

cat > "$PROJECT_DIR/Tests/BatteryTests/TimeFormattingTests.swift" << 'SWIFT_EOF'
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
SWIFT_EOF

file_created "Tests/BatteryTests/TimeFormattingTests.swift"

cat > "$PROJECT_DIR/Tests/BatteryTests/UsageDataTests.swift" << 'SWIFT_EOF'
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
SWIFT_EOF

file_created "Tests/BatteryTests/UsageDataTests.swift"

cat > "$PROJECT_DIR/Tests/BatteryTests/ColorThresholdsTests.swift" << 'SWIFT_EOF'
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
SWIFT_EOF

file_created "Tests/BatteryTests/ColorThresholdsTests.swift"

cat > "$PROJECT_DIR/Tests/BatteryTests/PlanTierTests.swift" << 'SWIFT_EOF'
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
SWIFT_EOF

file_created "Tests/BatteryTests/PlanTierTests.swift"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 6: Generate Bundle Script
# ═══════════════════════════════════════════════════════════════════════════════

step "Generating app bundle script..."

cat > "$PROJECT_DIR/Scripts/bundle.sh" << 'BUNDLE_EOF'
#!/usr/bin/env bash
#
# Bundle the Battery executable into a proper macOS .app bundle.
# Usage: ./Scripts/bundle.sh [release|debug]
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

CONFIG="${1:-debug}"
BUILD_DIR="$PROJECT_DIR/.build/$CONFIG"
APP_NAME="Battery"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"

echo "Bundling $APP_NAME ($CONFIG)..."

# Find the built binary
BINARY="$BUILD_DIR/$APP_NAME"
if [[ ! -f "$BINARY" ]]; then
    echo "Error: Binary not found at $BINARY"
    echo "Build first with: swift build -c $CONFIG"
    exit 1
fi

# Clean old bundle
rm -rf "$APP_BUNDLE"

# Create bundle structure
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy Info.plist
cp "$PROJECT_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Sign with entitlements (ad-hoc for development)
codesign --force --sign - \
    --entitlements "$PROJECT_DIR/Battery.entitlements" \
    "$APP_BUNDLE"

echo "Created: $APP_BUNDLE"
echo ""
echo "To run:"
echo "  open $APP_BUNDLE"
echo ""
echo "To install to /Applications:"
echo "  cp -r $APP_BUNDLE /Applications/"
BUNDLE_EOF

chmod +x "$PROJECT_DIR/Scripts/bundle.sh"
file_created "Scripts/bundle.sh"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 7: Generate Claude Code Hook Script
# ═══════════════════════════════════════════════════════════════════════════════

step "Generating Claude Code hook script..."

cat > "$PROJECT_DIR/Hooks/battery-hook.sh" << 'HOOK_EOF'
#!/usr/bin/env bash
#
# Battery - Claude Code Hook Script
#
# This hook writes session events to ~/.battery/events.jsonl
# so the Battery menu bar app can detect active coding sessions.
#
# Installation:
#   Add to your Claude Code hooks configuration:
#
#   "hooks": {
#     "SessionStart": [{ "command": "/path/to/battery-hook.sh SessionStart" }],
#     "SessionEnd":   [{ "command": "/path/to/battery-hook.sh SessionEnd" }],
#     "PostToolUse":  [{ "command": "/path/to/battery-hook.sh PostToolUse" }],
#     "Stop":         [{ "command": "/path/to/battery-hook.sh Stop" }]
#   }

set -euo pipefail

EVENT_TYPE="${1:-unknown}"
SESSION_ID="${CLAUDE_SESSION_ID:-$(uuidgen)}"
TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
EVENTS_DIR="$HOME/.battery"
EVENTS_FILE="$EVENTS_DIR/events.jsonl"

# Ensure events directory exists
mkdir -p "$EVENTS_DIR"

# Get ISO 8601 timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Build JSON event
if [[ -n "$TOOL_NAME" ]]; then
    EVENT_JSON="{\"event\":\"$EVENT_TYPE\",\"timestamp\":\"$TIMESTAMP\",\"session_id\":\"$SESSION_ID\",\"tool\":\"$TOOL_NAME\"}"
else
    EVENT_JSON="{\"event\":\"$EVENT_TYPE\",\"timestamp\":\"$TIMESTAMP\",\"session_id\":\"$SESSION_ID\"}"
fi

# Append to events file
echo "$EVENT_JSON" >> "$EVENTS_FILE"

# Rotate: keep only last 1000 events
if [[ $(wc -l < "$EVENTS_FILE") -gt 1000 ]]; then
    tail -500 "$EVENTS_FILE" > "$EVENTS_FILE.tmp"
    mv "$EVENTS_FILE.tmp" "$EVENTS_FILE"
fi
HOOK_EOF

chmod +x "$PROJECT_DIR/Hooks/battery-hook.sh"
file_created "Hooks/battery-hook.sh"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 8: Generate .gitignore
# ═══════════════════════════════════════════════════════════════════════════════

step "Generating .gitignore..."

cat > "$PROJECT_DIR/.gitignore" << 'GITIGNORE_EOF'
# Swift / SPM
.build/
.swiftpm/
Package.resolved
*.xcodeproj/
xcuserdata/
DerivedData/

# macOS
.DS_Store
*.app
*.dSYM

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# Claude Code
.claude/

# Battery app data (never commit user data)
*.db
events.jsonl
GITIGNORE_EOF

file_created ".gitignore"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 9: Generate Assets catalog (minimal)
# ═══════════════════════════════════════════════════════════════════════════════

step "Generating asset catalog..."

cat > "$PROJECT_DIR/Resources/Assets.xcassets/Contents.json" << 'ASSETS_EOF'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
ASSETS_EOF

cat > "$PROJECT_DIR/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json" << 'ICON_EOF'
{
  "images" : [
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
ICON_EOF

file_created "Resources/Assets.xcassets/"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 10: Initialize Git Repository
# ═══════════════════════════════════════════════════════════════════════════════

step "Initializing git repository..."

cd "$PROJECT_DIR"
if [[ ! -d ".git" ]]; then
    git init -q
    success "Git repository initialized"
else
    success "Git repository already exists"
fi

git add -A
if git diff --cached --quiet 2>/dev/null; then
    success "All files already committed (re-run detected)"
else
    git commit -q -m "Initial project scaffold for Battery menu bar app

- SPM-based macOS 13+ executable target with SwiftUI MenuBarExtra
- Full project structure: Models, Views, ViewModels, Services, Utilities
- KeychainService for reading Claude Code OAuth credentials
- AnthropicAPI client for usage polling with token refresh
- Adaptive polling service (30s active, 5m idle)
- Popover UI with circular gauges, countdown timers, color coding
- SQLite DatabaseService stub (Phase 2)
- Claude Code hook script for session awareness (Phase 3)
- App bundle script for proper macOS .app packaging
- Unit test stubs for formatting, models, and color thresholds"

    success "Initial commit created"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 11: Verify Build
# ═══════════════════════════════════════════════════════════════════════════════

step "Resolving package dependencies..."
cd "$PROJECT_DIR"
swift package resolve 2>&1 | while IFS= read -r line; do
    detail "$line"
done
success "Package dependencies resolved"

step "Attempting build..."
if swift build 2>&1 | tail -5; then
    success "Build succeeded!"
    BUILD_OK=true
else
    warn "Build had issues. This may need manual fixes."
    BUILD_OK=false
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Summary and Next Steps
# ═══════════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${BOLD}${GREEN}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║        Bootstrap Complete!               ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${RESET}"
echo ""

# Count files
SWIFT_COUNT=$(find "$PROJECT_DIR/Sources" -name "*.swift" | wc -l | tr -d ' ')
TEST_COUNT=$(find "$PROJECT_DIR/Tests" -name "*.swift" | wc -l | tr -d ' ')

echo -e "${BOLD}Project Summary:${RESET}"
echo -e "  Location:     ${CYAN}$PROJECT_DIR${RESET}"
echo -e "  Swift files:  ${CYAN}${SWIFT_COUNT} source + ${TEST_COUNT} test${RESET}"
echo -e "  Platform:     macOS 13.0+ (Ventura)"
echo -e "  Build system: Swift Package Manager"
echo ""

echo -e "${BOLD}Next Steps:${RESET}"
echo ""
echo -e "  ${BOLD}1. Build and run:${RESET}"
echo -e "     ${CYAN}cd $PROJECT_DIR${RESET}"
echo -e "     ${CYAN}swift build${RESET}"
echo -e "     ${CYAN}./Scripts/bundle.sh${RESET}"
echo -e "     ${CYAN}open Battery.app${RESET}"
echo ""
echo -e "  ${BOLD}2. Or run directly (no .app bundle):${RESET}"
echo -e "     ${CYAN}swift run Battery${RESET}"
echo ""
echo -e "  ${BOLD}3. Install Claude Code hooks:${RESET}"
echo -e "     Add to ${CYAN}~/.claude/settings.json${RESET}:"
echo -e "     ${DIM}\"hooks\": {"
echo -e "       \"SessionStart\": [{ \"command\": \"$PROJECT_DIR/Hooks/battery-hook.sh SessionStart\" }],"
echo -e "       \"SessionEnd\":   [{ \"command\": \"$PROJECT_DIR/Hooks/battery-hook.sh SessionEnd\" }],"
echo -e "       \"PostToolUse\":  [{ \"command\": \"$PROJECT_DIR/Hooks/battery-hook.sh PostToolUse\" }],"
echo -e "       \"Stop\":         [{ \"command\": \"$PROJECT_DIR/Hooks/battery-hook.sh Stop\" }]"
echo -e "     }${RESET}"
echo ""
echo -e "  ${BOLD}4. Run tests:${RESET}"
echo -e "     ${CYAN}swift test${RESET}"
echo ""
echo -e "  ${BOLD}5. Implementation order (see PLAN):${RESET}"
echo -e "     ${DIM}Phase 1: Wire up real API data -> display in menu bar${RESET}"
echo -e "     ${DIM}Phase 2: SQLite history, burn rate, charts, notifications${RESET}"
echo -e "     ${DIM}Phase 3: Hooks integration, settings, launch at login${RESET}"
echo ""
echo -e "  ${BOLD}Plan document:${RESET}"
echo -e "     ${CYAN}$PROJECT_DIR/.claude/temp/PLAN_BATTERY.md${RESET}"
echo ""
