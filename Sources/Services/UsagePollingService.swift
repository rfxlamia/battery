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
            let token = try await tokenRefreshService.refreshIfNeeded(
                credentials: credentials,
                keychainService: keychainService
            )
            let usage = try await api.fetchUsage(accessToken: token)
            self.latestUsage = usage
            self.lastError = nil
        } catch {
            self.lastError = error
            // On 401 or token refresh failure, try recovery
            if let apiError = error as? AnthropicAPI.APIError, apiError.isUnauthorized {
                await retryWithRefresh()
            } else if error is TokenRefreshService.TokenError {
                await retryWithRefresh()
            }
        }
    }

    @MainActor
    private func retryWithRefresh() async {
        do {
            // Try OAuth refresh using Battery's cached credentials (no password prompt)
            let credentials = try await keychainService.readCredentials(forceRefresh: true)
            let tokenResponse = try await tokenRefreshService.forceRefresh(refreshToken: credentials.refreshToken)
            let updated = KeychainService.Credentials(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken ?? credentials.refreshToken,
                expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn)),
                subscriptionType: credentials.subscriptionType,
                rateLimitTier: credentials.rateLimitTier
            )
            await keychainService.updateCachedCredentials(updated)
            let usage = try await api.fetchUsage(accessToken: tokenResponse.accessToken)
            self.latestUsage = usage
            self.lastError = nil
        } catch {
            // OAuth refresh failed (e.g. refresh token expired) — last resort:
            // read from Claude Code's keychain (may prompt once)
            await retryFromClaudeCodeKeychain()
        }
    }

    @MainActor
    private func retryFromClaudeCodeKeychain() async {
        do {
            let credentials = try await keychainService.readFromClaudeCodeAndCache()
            let token = try await tokenRefreshService.refreshIfNeeded(
                credentials: credentials,
                keychainService: keychainService
            )
            let usage = try await api.fetchUsage(accessToken: token)
            self.latestUsage = usage
            self.lastError = nil
        } catch {
            self.lastError = error
        }
    }
}
