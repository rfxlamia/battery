import SwiftUI

/// App settings backed by UserDefaults via @AppStorage.
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("notifyAt80") var notifyAt80: Bool = true
    @AppStorage("notifyAt90") var notifyAt90: Bool = true
    @AppStorage("notifyAt95") var notifyAt95: Bool = true
    @AppStorage("showMenuBarText") var showMenuBarText: Bool = true
    @AppStorage("menuBarDisplayMode") var menuBarDisplayMode: String = "percentageAndTime"
    @AppStorage("pollIntervalActive") var pollIntervalActive: Double = 30
    @AppStorage("pollIntervalIdle") var pollIntervalIdle: Double = 300
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("dataRetentionDays") var dataRetentionDays: Int = 90
}
