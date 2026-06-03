import SwiftUI

@main
struct MochaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var client = YTDLPClient()
    @StateObject private var theme = AppTheme()

    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    @AppStorage("menuBarIcon") private var menuBarIcon = "cup.and.saucer.fill"

    init() {
        // Register defaults so @AppStorage and raw UserDefaults reads agree
        // (the menu-bar lifecycle in AppDelegate depends on this consistency).
        UserDefaults.standard.register(defaults: [
            "showMenuBarIcon": true,
            "menuBarIcon": "cup.and.saucer.fill",
            "menuBarOnly": false,
        ])
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            MochaView()
                .environmentObject(client)
                .environmentObject(theme)
                .task { await client.bootstrap() }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 500, height: 620)

        MenuBarExtra("Mocha", systemImage: menuBarIcon, isInserted: $showMenuBarIcon) {
            MenuBarView()
                .environmentObject(client)
                .environmentObject(theme)
        }
        .menuBarExtraStyle(.window)
    }
}
