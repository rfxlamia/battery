import Foundation
import Security

/// Reads Claude Code OAuth credentials from the macOS Keychain.
///
/// To avoid repeated macOS password prompts, credentials are copied from
/// Claude Code's keychain item into Battery's own keychain item on first
/// launch. Subsequent reads always use Battery's item (which never triggers
/// a prompt). When the access token nears expiry, the caller refreshes it
/// via OAuth using the stored refresh token — Claude Code's keychain is
/// only re-read as a last resort if the refresh token itself is invalid.
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

    // MARK: - Constants

    private static let claudeCodeService = "Claude Code-credentials"
    private static let batteryService = "com.allthingsclaude.battery-credentials"
    private static let batteryAccount = "cached-oauth"

    /// Re-read when token expires within this window.
    private let cacheRefreshBuffer: TimeInterval = 600 // 10 minutes

    // MARK: - In-memory cache

    private var cachedCredentials: Credentials?

    /// Returns credentials using a three-tier lookup:
    /// 1. In-memory cache (if fresh)
    /// 2. Battery's own keychain item (no prompt) — returns even if near-expiry,
    ///    since the caller can refresh via OAuth using the refresh token
    /// 3. Claude Code's keychain item (may prompt once on first run)
    func readCredentials(forceRefresh: Bool = false) throws -> Credentials {
        // 1. Memory cache
        if !forceRefresh, let cached = cachedCredentials,
           cached.expiresAt.timeIntervalSinceNow > cacheRefreshBuffer {
            return cached
        }

        // 2. Battery's own keychain item (never prompts).
        //    Returns even if near-expiry — the caller handles OAuth refresh.
        if let credentials = try? readFromBatteryKeychain() {
            cachedCredentials = credentials
            return credentials
        }

        // 3. Claude Code's keychain item (may prompt once)
        let credentials = try readFromClaudeCodeKeychain()
        cachedCredentials = credentials
        saveToBatteryKeychain(credentials)
        return credentials
    }

    /// Reads directly from Claude Code's keychain (may trigger macOS password prompt).
    /// Use only as a last resort when Battery's cached refresh token is invalid.
    func readFromClaudeCodeAndCache() throws -> Credentials {
        let credentials = try readFromClaudeCodeKeychain()
        cachedCredentials = credentials
        saveToBatteryKeychain(credentials)
        return credentials
    }

    /// Clears the in-memory cache, forcing the next read to check keychain.
    func invalidateCache() {
        cachedCredentials = nil
    }

    /// Writes updated credentials to Battery's own keychain item and memory cache.
    func updateCachedCredentials(_ credentials: Credentials) {
        cachedCredentials = credentials
        saveToBatteryKeychain(credentials)
    }

    // MARK: - Battery's own keychain item (prompt-free)

    private func readFromBatteryKeychain() throws -> Credentials {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.batteryService,
            kSecAttrAccount as String: Self.batteryAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.itemNotFound
        }

        return try parseCredentials(data)
    }

    private func saveToBatteryKeychain(_ credentials: Credentials) {
        let json = serializeCredentials(credentials)
        guard let data = try? JSONSerialization.data(withJSONObject: json) else { return }

        // Try updating first, then adding.
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.batteryService,
            kSecAttrAccount as String: Self.batteryAccount,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    private func serializeCredentials(_ credentials: Credentials) -> [String: Any] {
        return [
            "claudeAiOauth": [
                "accessToken": credentials.accessToken,
                "refreshToken": credentials.refreshToken,
                "expiresAt": credentials.expiresAt.timeIntervalSince1970 * 1000.0,
                "subscriptionType": credentials.subscriptionType,
                "rateLimitTier": credentials.rateLimitTier,
            ] as [String: Any]
        ]
    }

    // MARK: - Claude Code's keychain item (may prompt)

    private func readFromClaudeCodeKeychain() throws -> Credentials {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.claudeCodeService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
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

    // MARK: - Parsing

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
