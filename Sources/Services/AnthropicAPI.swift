import Foundation

/// Client for the Anthropic OAuth usage API.
actor AnthropicAPI {

    private static let logDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".battery")
    private static let logFile = logDir.appendingPathComponent("rate-limits.log")

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
        request.setValue(Constants.userAgent, forHTTPHeaderField: "User-Agent")
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
                Self.logRateLimitHeaders(httpResponse, body: String(data: data, encoding: .utf8))
                throw APIError.rateLimited(retryAfter: retryAfter)
            default:
                let body = String(data: data, encoding: .utf8) ?? "No body"
                throw APIError.serverError(statusCode: httpResponse.statusCode, body: body)
            }

            #if DEBUG
            if let rawJSON = String(data: data, encoding: .utf8) {
                let debugPath = FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent(".battery_debug_response.json").path
                try? rawJSON.write(toFile: debugPath, atomically: true, encoding: .utf8)
                try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: debugPath)
            }
            #endif

            do {
                return try JSONDecoder().decode(UsageResponse.self, from: data)
            } catch {
                #if DEBUG
                let debugPath = FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent(".battery_debug_error.txt").path
                try? "\(error)".write(toFile: debugPath, atomically: true, encoding: .utf8)
                try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: debugPath)
                #endif
                throw APIError.decodingError(error)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    /// Append rate limit headers to ~/.battery/rate-limits.log
    private static func logRateLimitHeaders(_ response: HTTPURLResponse, body: String?) {
        let fm = FileManager.default
        try? fm.createDirectory(at: logDir, withIntermediateDirectories: true)

        let timestamp = ISO8601DateFormatter().string(from: Date())
        var lines = ["[\(timestamp)] 429 Rate Limited"]

        // Log all rate-limit related headers
        let headers = response.allHeaderFields
        for (key, value) in headers {
            let name = "\(key)"
            if name.lowercased().contains("ratelimit") ||
               name.lowercased().contains("rate-limit") ||
               name.lowercased() == "retry-after" {
                lines.append("  \(name): \(value)")
            }
        }

        if let body = body, !body.isEmpty {
            lines.append("  Body: \(body)")
        }

        lines.append("")
        let entry = lines.joined(separator: "\n") + "\n"

        if let handle = try? FileHandle(forWritingTo: logFile) {
            handle.seekToEndOfFile()
            handle.write(entry.data(using: .utf8)!)
            handle.closeFile()
        } else {
            try? entry.write(to: logFile, atomically: true, encoding: .utf8)
        }
        try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: logFile.path)
    }
}
