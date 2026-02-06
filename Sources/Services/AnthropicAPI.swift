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
