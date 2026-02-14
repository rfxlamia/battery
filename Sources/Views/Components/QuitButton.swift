import SwiftUI

/// A plain-styled "Quit" button that terminates the app.
struct QuitButton: View {
    var body: some View {
        Button(action: { NSApplication.shared.terminate(nil) }) {
            Text("Quit")
                .font(.caption)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .focusable(false)
    }
}
