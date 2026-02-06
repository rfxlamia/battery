import SwiftUI

/// Display modes for menu bar text.
enum MenuBarDisplayMode: String, CaseIterable {
    case percentageAndTime = "percentageAndTime"
    case percentageOnly = "percentageOnly"
    case timeOnly = "timeOnly"
    case iconOnly = "iconOnly"

    var displayName: String {
        switch self {
        case .percentageAndTime: return "49% · 1h 23m"
        case .percentageOnly: return "49%"
        case .timeOnly: return "1h 23m"
        case .iconOnly: return "Icon only"
        }
    }
}

/// App settings backed by UserDefaults via @AppStorage.
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // Notifications
    @AppStorage("notifyAt80") var notifyAt80: Bool = true
    @AppStorage("notifyAt90") var notifyAt90: Bool = true
    @AppStorage("notifyAt95") var notifyAt95: Bool = true

    // Display
    @AppStorage("showMenuBarIcon") var showMenuBarIcon: Bool = true
    @AppStorage("showMenuBarText") var showMenuBarText: Bool = true
    @AppStorage("menuBarDisplayMode") var menuBarDisplayMode: String = MenuBarDisplayMode.percentageAndTime.rawValue
    @AppStorage("showPercentageRemaining") var showPercentageRemaining: Bool = false
    @AppStorage("showTimeSinceReset") var showTimeSinceReset: Bool = false

    // Polling
    @AppStorage("pollIntervalActive") var pollIntervalActive: Double = 30
    @AppStorage("pollIntervalIdle") var pollIntervalIdle: Double = 300

    // General
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false

    // Data
    @AppStorage("dataRetentionDays") var dataRetentionDays: Int = 90

    var displayMode: MenuBarDisplayMode {
        get { MenuBarDisplayMode(rawValue: menuBarDisplayMode) ?? .percentageAndTime }
        set { menuBarDisplayMode = newValue.rawValue }
    }
}
