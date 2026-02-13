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
        case noRefreshToken

        var errorDescription: String? {
            switch self {
            case .refreshFailed(let code, let body):
                return "Token refresh failed (HTTP \(code)): \(body)"
            case .networkError(let error):
                return "Network error during token refresh: \(error.localizedDescription)"
            case .noRefreshToken:
                return "No refresh token available"
            }
        }
    }

    private let refreshBufferSeconds: TimeInterval = 300 // 5 minutes

    /// Returns a valid access token, refreshing if needed.
    /// Returns optional updated tokens (nil if no refresh was needed).
    func refreshIfNeeded(tokens: StoredTokens) async throws -> (accessToken: String, updatedTokens: StoredTokens?) {
        if tokens.expiryDate.timeIntervalSinceNow > refreshBufferSeconds {
            return (tokens.accessToken, nil)
        }

        guard let refreshToken = tokens.refreshToken else {
            throw TokenError.noRefreshToken
        }

        let response = try await forceRefresh(refreshToken: refreshToken)
        let updated = StoredTokens(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken ?? tokens.refreshToken,
            expiresIn: response.expiresIn
        )
        return (response.accessToken, updated)
    }

    /// Force a token refresh using the refresh token.
    func forceRefresh(refreshToken: String) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: Constants.oauthTokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Constants.userAgent, forHTTPHeaderField: "User-Agent")

        let body: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": Constants.oauthClientId,
            "scope": Constants.oauthScopes,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

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
