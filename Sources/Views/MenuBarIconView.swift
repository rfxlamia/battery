import SwiftUI

/// The label displayed in the macOS menu bar.
struct MenuBarIconView: View {
    @ObservedObject var viewModel: UsageViewModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: viewModel.menuBarSymbol)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(viewModel.sessionColor)

            if viewModel.isConnected {
                let text = viewModel.menuBarText
                if !text.isEmpty {
                    Text(text)
                        .font(.caption)
                        .monospacedDigit()
                }
            } else {
                Text("--")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
