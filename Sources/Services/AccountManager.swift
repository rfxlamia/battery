import Foundation
import Combine
import Security

/// Manages multiple accounts and their token storage.
///
/// Tokens are stored in the macOS Keychain. Account metadata lives at:
/// ```
/// ~/.battery/accounts.json  — Array of Account (0600 perms)
/// ```
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

        // Migrate tokens from disk to Keychain (one-time)
        migrateTokensFromDiskToKeychain()

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

        // Remove from Keychain
        keychainDelete(accountId: id)

        // Clean up any leftover disk tokens
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
            keychainDelete(accountId: id)
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

    func getTokens(for accountId: UUID) -> StoredTokens? {
        // Read from Keychain
        if let tokens = keychainLoad(accountId: accountId) {
            return tokens
        }

        // Fall back to disk for pre-migration installs
        let tokenFile = accountsDir
            .appendingPathComponent(accountId.uuidString)
            .appendingPathComponent("tokens.json")
        guard fileManager.fileExists(atPath: tokenFile.path) else { return nil }
        do {
            let data = try Data(contentsOf: tokenFile)
            let tokens = try JSONDecoder().decode(StoredTokens.self, from: data)
            // Migrate to Keychain, then remove disk copy
            keychainSave(tokens: tokens, accountId: accountId)
            try? fileManager.removeItem(at: tokenFile)
            return tokens
        } catch {
            print("Failed to read tokens for \(accountId): \(error.localizedDescription)")
            return nil
        }
    }

    func saveTokens(_ tokens: StoredTokens, for accountId: UUID) {
        keychainSave(tokens: tokens, accountId: accountId)
    }

    // MARK: - Keychain Helpers

    private func keychainSave(tokens: StoredTokens, accountId: UUID) {
        guard let data = try? JSONEncoder().encode(tokens) else { return }

        // Delete existing item first (SecItemAdd fails on duplicate)
        keychainDelete(accountId: accountId)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: accountId.uuidString,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Keychain save failed for \(accountId): \(status)")
        }
    }

    private func keychainLoad(accountId: UUID) -> StoredTokens? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: accountId.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }

        return try? JSONDecoder().decode(StoredTokens.self, from: data)
    }

    @discardableResult
    private func keychainDelete(accountId: UUID) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: accountId.uuidString,
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Migration

    private func migrateTokensFromDiskToKeychain() {
        guard fileManager.fileExists(atPath: accountsDir.path) else { return }

        var migratedAny = false
        for account in accounts {
            let tokenFile = accountsDir
                .appendingPathComponent(account.id.uuidString)
                .appendingPathComponent("tokens.json")
            guard fileManager.fileExists(atPath: tokenFile.path) else { continue }

            do {
                let data = try Data(contentsOf: tokenFile)
                let tokens = try JSONDecoder().decode(StoredTokens.self, from: data)
                // Only migrate if not already in Keychain
                if keychainLoad(accountId: account.id) == nil {
                    keychainSave(tokens: tokens, accountId: account.id)
                }
                try fileManager.removeItem(at: tokenFile)
                migratedAny = true
            } catch {
                print("Migration failed for \(account.id): \(error.localizedDescription)")
            }
        }

        // Clean up the accounts directory if all token files were migrated
        if migratedAny {
            try? fileManager.removeItem(at: accountsDir)
        }
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
