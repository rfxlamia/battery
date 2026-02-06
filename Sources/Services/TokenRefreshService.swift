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
