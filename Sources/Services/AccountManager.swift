import Foundation
import Combine
import Security

/// Manages multiple accounts and their token storage.
///
/// Tokens are stored in the Data Protection keychain when available (release builds
/// signed with a team ID and the `keychain-access-groups` entitlement). Falls back
/// to file-based storage in `~/.battery/tokens/` (0600 perms) for dev builds.
/// Account metadata lives at `~/.battery/accounts.json` (0600 perms).
@MainActor
class AccountManager: ObservableObject {
    @Published var accounts: [Account] = []
    @Published var selectedAccountId: UUID?

    private let fileManager = FileManager.default
    private static let keychainService = "com.allthingsclaude.battery"

    private var batteryDir: URL {
        fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".battery")
    }

    private var accountsFile: URL {
        batteryDir.appendingPathComponent("accounts.json")
    }

    private var accountsDir: URL {
        batteryDir.appendingPathComponent("accounts")
    }

    var selectedAccount: Account? {
        guard let id = selectedAccountId else { return accounts.first }
        return accounts.first(where: { $0.id == id })
    }

    var hasAccounts: Bool {
        !accounts.isEmpty
    }

    // MARK: - Load / Save

    func load() {
        guard fileManager.fileExists(atPath: accountsFile.path) else { return }
        do {
            let data = try Data(contentsOf: accountsFile)
            accounts = try JSONDecoder().decode([Account].self, from: data)
        } catch {
            print("Failed to load accounts: \(error.localizedDescription)")
        }

        if let savedId = UserDefaults.standard.string(forKey: "selectedAccountId"),
           let uuid = UUID(uuidString: savedId),
           accounts.contains(where: { $0.id == uuid }) {
            selectedAccountId = uuid
        } else {
            selectedAccountId = accounts.first?.id
        }
    }

    func save() {
        do {
            try fileManager.createDirectory(at: batteryDir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(accounts)
            try data.write(to: accountsFile, options: .atomic)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: accountsFile.path)
        } catch {
            print("Failed to save accounts: \(error.localizedDescription)")
        }
    }

    // MARK: - Account Management

    func addAccount(_ account: Account, tokens: StoredTokens) {
        accounts.append(account)
        saveTokens(tokens, for: account.id)
        save()
        selectAccount(id: account.id)
    }

    func removeAccount(id: UUID) {
        accounts.removeAll(where: { $0.id == id })

        // Remove tokens from all storage backends
        deleteTokens(for: id)

        // Clean up any leftover legacy tokens
        let tokenDir = accountsDir.appendingPathComponent(id.uuidString)
        try? fileManager.removeItem(at: tokenDir)

        // Select next account if the removed one was selected
        if selectedAccountId == id {
            selectedAccountId = accounts.first?.id
            persistSelectedAccountId()
        }

        save()
    }

    func removeAllAccounts() {
        let ids = accounts.map(\.id)
        for id in ids {
            deleteTokens(for: id)
            let tokenDir = accountsDir.appendingPathComponent(id.uuidString)
            try? fileManager.removeItem(at: tokenDir)
        }
        accounts.removeAll()
        selectedAccountId = nil
        persistSelectedAccountId()
        save()
    }

    func selectAccount(id: UUID) {
        guard accounts.contains(where: { $0.id == id }) else { return }
        selectedAccountId = id
        persistSelectedAccountId()
    }

    func updateAccount(_ account: Account) {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else { return }
        accounts[index] = account
        save()
    }

    // MARK: - Token Storage

    /// Cached after first probe — `true` when the Data Protection keychain is usable.
    private var _dataProtectionAvailable: Bool?

    /// Returns `true` when the app has the `keychain-access-groups` entitlement
    /// and is signed with a team ID (release builds). Probed once by writing and
    /// deleting a sentinel item.
    private var isDataProtectionAvailable: Bool {
        if let cached = _dataProtectionAvailable { return cached }

        let probe: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: "__dp_probe__",
            kSecValueData as String: Data([0x00]),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecUseDataProtectionKeychain as String: true,
        ]
        let addStatus = SecItemAdd(probe as CFDictionary, nil)
        if addStatus == errSecSuccess || addStatus == errSecDuplicateItem {
            // Clean up probe
            var deleteQuery = probe
            deleteQuery.removeValue(forKey: kSecValueData as String)
            deleteQuery.removeValue(forKey: kSecAttrAccessible as String)
            SecItemDelete(deleteQuery as CFDictionary)
            _dataProtectionAvailable = true
        } else {
            _dataProtectionAvailable = false
        }
        return _dataProtectionAvailable!
    }

    private var tokensDir: URL {
        batteryDir.appendingPathComponent("tokens")
    }

    private func tokenFile(for accountId: UUID) -> URL {
        tokensDir.appendingPathComponent("\(accountId.uuidString).json")
    }

    func getTokens(for accountId: UUID) -> StoredTokens? {
        // 1. Data Protection keychain (release builds)
        if isDataProtectionAvailable, let tokens = dpKeychainLoad(accountId: accountId) {
            return tokens
        }

        // 2. File-based storage (dev builds, or migrated tokens)
        let file = tokenFile(for: accountId)
        if fileManager.fileExists(atPath: file.path) {
            do {
                let data = try Data(contentsOf: file)
                return try JSONDecoder().decode(StoredTokens.self, from: data)
            } catch {
                print("Failed to read tokens for \(accountId): \(error.localizedDescription)")
            }
        }

        // 3. Migrate from legacy file-based keychain (one-time)
        if let tokens = migrateFromLegacyKeychain(accountId: accountId) {
            return tokens
        }

        // 4. Legacy: old per-account directory structure
        let legacyFile = accountsDir
            .appendingPathComponent(accountId.uuidString)
            .appendingPathComponent("tokens.json")
        guard fileManager.fileExists(atPath: legacyFile.path) else { return nil }
        do {
            let data = try Data(contentsOf: legacyFile)
            let tokens = try JSONDecoder().decode(StoredTokens.self, from: data)
            saveTokens(tokens, for: accountId)
            try? fileManager.removeItem(at: legacyFile)
            return tokens
        } catch {
            print("Failed to read legacy tokens for \(accountId): \(error.localizedDescription)")
            return nil
        }
    }

    func saveTokens(_ tokens: StoredTokens, for accountId: UUID) {
        if isDataProtectionAvailable {
            dpKeychainSave(tokens: tokens, accountId: accountId)
        } else {
            saveTokensToFile(tokens, for: accountId)
        }
    }

    func deleteTokens(for accountId: UUID) {
        dpKeychainDelete(accountId: accountId)
        deleteTokenFile(for: accountId)
    }

    // MARK: - Data Protection Keychain (release builds)

    private func dpKeychainSave(tokens: StoredTokens, accountId: UUID) {
        guard let data = try? JSONEncoder().encode(tokens) else { return }

        dpKeychainDelete(accountId: accountId)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: accountId.uuidString,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecUseDataProtectionKeychain as String: true,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("DP Keychain save failed (\(status)), falling back to file")
            saveTokensToFile(tokens, for: accountId)
        }
    }

    private func dpKeychainLoad(accountId: UUID) -> StoredTokens? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: accountId.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseDataProtectionKeychain as String: true,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(StoredTokens.self, from: data)
    }

    @discardableResult
    private func dpKeychainDelete(accountId: UUID) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: accountId.uuidString,
            kSecUseDataProtectionKeychain as String: true,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - File-Based Token Storage (dev builds / fallback)

    private func saveTokensToFile(_ tokens: StoredTokens, for accountId: UUID) {
        do {
            try fileManager.createDirectory(at: tokensDir, withIntermediateDirectories: true)
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: tokensDir.path)
            let data = try JSONEncoder().encode(tokens)
            try data.write(to: tokenFile(for: accountId), options: .atomic)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tokenFile(for: accountId).path)
        } catch {
            print("Failed to save tokens for \(accountId): \(error.localizedDescription)")
        }
    }

    private func deleteTokenFile(for accountId: UUID) {
        try? fileManager.removeItem(at: tokenFile(for: accountId))
    }

    // MARK: - Legacy Keychain Migration

    /// One-time: read from the old file-based keychain, save to current storage, delete legacy entry.
    private func migrateFromLegacyKeychain(accountId: UUID) -> StoredTokens? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: accountId.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data,
              let tokens = try? JSONDecoder().decode(StoredTokens.self, from: data) else {
            return nil
        }

        // Save to current storage and remove legacy entry
        saveTokens(tokens, for: accountId)
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: accountId.uuidString,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        return tokens
    }

    // MARK: - Private

    private func persistSelectedAccountId() {
        if let id = selectedAccountId {
            UserDefaults.standard.set(id.uuidString, forKey: "selectedAccountId")
        } else {
            UserDefaults.standard.removeObject(forKey: "selectedAccountId")
        }
    }
}
