import Foundation
import Combine

/// Manages multiple accounts and their token storage on disk.
///
/// Storage layout:
/// ```
/// ~/.battery/accounts.json                  — Array of Account
/// ~/.battery/accounts/<uuid>/tokens.json    — StoredTokens (0600 perms)
/// ```
@MainActor
class AccountManager: ObservableObject {
    @Published var accounts: [Account] = []
    @Published var selectedAccountId: UUID?

    private let fileManager = FileManager.default

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

        // Remove token directory
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
        let tokenFile = accountsDir
            .appendingPathComponent(accountId.uuidString)
            .appendingPathComponent("tokens.json")
        guard fileManager.fileExists(atPath: tokenFile.path) else { return nil }
        do {
            let data = try Data(contentsOf: tokenFile)
            return try JSONDecoder().decode(StoredTokens.self, from: data)
        } catch {
            print("Failed to read tokens for \(accountId): \(error.localizedDescription)")
            return nil
        }
    }

    func saveTokens(_ tokens: StoredTokens, for accountId: UUID) {
        let tokenDir = accountsDir.appendingPathComponent(accountId.uuidString)
        let tokenFile = tokenDir.appendingPathComponent("tokens.json")
        do {
            try fileManager.createDirectory(at: tokenDir, withIntermediateDirectories: true,
                                             attributes: [.posixPermissions: 0o700])
            let data = try JSONEncoder().encode(tokens)
            try data.write(to: tokenFile, options: .atomic)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tokenFile.path)
        } catch {
            print("Failed to save tokens for \(accountId): \(error.localizedDescription)")
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
