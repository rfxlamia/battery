import SwiftUI

/// App settings panel. Phase 3 implementation.
struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        // Phase 3: Full settings panel
        Form {
            Section("Notifications") {
                Toggle("Notify at 80%", isOn: $settings.notifyAt80)
                Toggle("Notify at 90%", isOn: $settings.notifyAt90)
                Toggle("Notify at 95%", isOn: $settings.notifyAt95)
            }
        }
        .padding()
        .frame(width: 300)
    }
}
