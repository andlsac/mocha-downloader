import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {

    /// Keep the app alive in the menu bar when the window closes, so the
    /// menu-bar version actually persists instead of quitting the whole app.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !UserDefaults.standard.bool(forKey: "showMenuBarIcon")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyActivationPolicy()
    }

    /// Dock-icon click (or relaunch) with no open window → reopen the window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows where window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
            }
            NotificationCenter.default.post(name: .openMainWindow, object: nil)
        }
        return true
    }

    func applyActivationPolicy() {
        let menuBarOnly = UserDefaults.standard.bool(forKey: "menuBarOnly")
        NSApp.setActivationPolicy(menuBarOnly ? .accessory : .regular)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard url.scheme == "mocha",
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let videoURLString = components.queryItems?.first(where: { $0.name == "url" })?.value,
                  let videoURL = URL(string: videoURLString),
                  videoURL.scheme == "https" || videoURL.scheme == "http"
            else { continue }
            NotificationCenter.default.post(name: .addVideoURL, object: videoURLString)
        }
    }
}

extension Notification.Name {
    static let addVideoURL = Notification.Name("mocha.addVideoURL")
    static let openMainWindow = Notification.Name("mocha.openMainWindow")
}
