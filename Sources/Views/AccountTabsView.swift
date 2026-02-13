import SwiftUI

/// Horizontal tab bar for switching between accounts.
struct AccountTabsView: View {
    let accounts: [Account]
    let selectedAccountId: UUID?
    let onSelect: (UUID) -> Void
    let onAddAccount: () -> Void

    private let maxAccounts = 5

    var body: some View {
        HStack(spacing: 8) {
            Picker("Account", selection: Binding(
                get: { selectedAccountId ?? accounts.first?.id ?? UUID() },
                set: { onSelect($0) }
            )) {
                ForEach(accounts) { account in
                    Text(account.name).tag(account.id)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if accounts.count < maxAccounts {
                Button(action: onAddAccount) {
                    Image(systemName: "plus")
                        .font(.caption2)
                }
                .controlSize(.small)
                .focusable(false)
                .help("Add account")
            }
        }
    }
}
