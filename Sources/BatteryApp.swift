import SwiftUI

@main
struct BatteryApp: App {
    @StateObject private var viewModel = UsageViewModel()
    @StateObject private var updaterService = UpdaterService()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(viewModel: viewModel, updaterService: updaterService)
                .frame(width: 320)
        } label: {
            MenuBarIconView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}
