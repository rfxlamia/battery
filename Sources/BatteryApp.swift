import SwiftUI

@main
struct BatteryApp: App {
    @StateObject private var viewModel = UsageViewModel()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(viewModel: viewModel)
                .frame(width: 320)
        } label: {
            MenuBarIconView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}
