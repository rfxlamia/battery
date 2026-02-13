import Foundation
import Combine

/// Coordinates periodic polling of the Anthropic usage API.
class UsagePollingService: ObservableObject {
    @Published var latestUsage: UsageResponse?
    @Published var lastError: Error?
    @Published var isPolling: Bool = false
    @Published var needsReauth: Bool = false

    private let tokenRefreshService = TokenRefreshService()
    private let api = AnthropicAPI()
    private var pollingTask: Task<Void, Never>?
    private var currentInterval: TimeInterval
    private var currentTokens: StoredTokens?
    private var onTokensRefreshed: ((StoredTokens) -> Void)?

    init(interval: TimeInterval = Constants.defaultPollInterval) {
        self.currentInterval = interval
    }

    /// Configure the polling service with tokens and a callback for when tokens are refreshed.
    func configure(tokens: StoredTokens?, onTokensRefreshed: @escaping (StoredTokens) -> Void) {
        self.currentTokens = tokens
        self.onTokensRefreshed = onTokensRefreshed
        self.needsReauth = (tokens == nil)
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
        guard let tokens = currentTokens else {
            needsReauth = true
            return
        }

        do {
            let (accessToken, updatedTokens) = try await tokenRefreshService.refreshIfNeeded(tokens: tokens)

            if let updated = updatedTokens {
                currentTokens = updated
                onTokensRefreshed?(updated)
            }

            let usage = try await api.fetchUsage(accessToken: accessToken)
            self.latestUsage = usage
            self.lastError = nil
            self.needsReauth = false
        } catch {
            self.lastError = error

            // On 401 or token refresh failure, try force refresh
            if let apiError = error as? AnthropicAPI.APIError, apiError.isUnauthorized {
                await retryWithForceRefresh()
            } else if error is TokenRefreshService.TokenError {
                self.needsReauth = true
            }
        }
    }

    @MainActor
    private func retryWithForceRefresh() async {
        guard let tokens = currentTokens, let refreshToken = tokens.refreshToken else {
            needsReauth = true
            return
        }

        do {
            let response = try await tokenRefreshService.forceRefresh(refreshToken: refreshToken)
            let updated = StoredTokens(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken ?? tokens.refreshToken,
                expiresIn: response.expiresIn
            )
            currentTokens = updated
            onTokensRefreshed?(updated)

            let usage = try await api.fetchUsage(accessToken: response.accessToken)
            self.latestUsage = usage
            self.lastError = nil
            self.needsReauth = false
        } catch {
            self.lastError = error
            self.needsReauth = true
        }
    }
}
