import SwiftUI

/// Color theme for the app UI.
enum ColorTheme: String, CaseIterable {
    case `default`  // Warm terracotta monochrome palette
    case classic    // Multi-color green/yellow/orange/red

    var displayName: String {
        switch self {
        case .default: return "Default"
        case .classic: return "Classic"
        }
    }

    // MARK: - Default Theme Colors

    /// Primary brand color — terracotta orange (#D97757)
    static let brand = Color(hex: 0xD97757)
    /// Darker brand variant (#B85A3A)
    static let brandDark = Color(hex: 0xB85A3A)
    /// Lighter brand variant (#F0C4AE)
    static let brandLight = Color(hex: 0xF0C4AE)
    /// Very light brand variant (#F5D9CB)
    static let brandLighter = Color(hex: 0xF5D9CB)
    /// Track/background color (#E6E0D8)
    static let trackBG = Color(hex: 0xE6E0D8)
    /// Screen background (#FAF8F4)
    static let background = Color(hex: 0xFAF8F4)
}

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
    @AppStorage("colorTheme") var colorTheme: String = ColorTheme.default.rawValue
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

    var activeTheme: ColorTheme {
        get { ColorTheme(rawValue: colorTheme) ?? .default }
        set { colorTheme = newValue.rawValue }
    }
}
