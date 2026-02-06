import SwiftUI

/// View model for the settings panel.
/// Phase 3: Full implementation.
class SettingsViewModel: ObservableObject {
    @Published var settings = AppSettings.shared
}
