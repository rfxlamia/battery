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
