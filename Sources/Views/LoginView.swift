import SwiftUI

/// Shown when no accounts are configured. Prompts user to sign in via OAuth.
struct LoginView: View {
    @ObservedObject var viewModel: UsageViewModel

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            if let iconURL = Bundle.main.url(forResource: "BatteryIcon", withExtension: "png"),
               let nsImage = NSImage(contentsOf: iconURL) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 128, height: 128)
                    .padding(.top, 16)
            }

            VStack(spacing: 4) {
                Text("Claude Battery")
                    .font(.headline)
                Text("Monitor your Claude usage")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error = viewModel.error {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            if viewModel.oauthService.isAuthenticating {
                ProgressView()
                    .controlSize(.small)
                Text("Waiting for browser...")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                Button("Sign in with Claude") {
                    NSApp.keyWindow?.close()
                    viewModel.startOAuthLogin()
                }
                .controlSize(.large)
                .focusable(false)
            }

            Spacer()

            HStack {
                Spacer()
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Text("Quit")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .focusable(false)
            }
        }
        .padding(16)
        .frame(width: 320)
        .background(AppSettings.shared.activeTheme == .default ? ColorTheme.background : ColorTheme.classicBackground)
    }
}
