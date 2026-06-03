import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var theme: AppTheme
    @StateObject private var updater = Updater()
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    @AppStorage("menuBarIcon") private var menuBarIcon = "cup.and.saucer.fill"
    @AppStorage("menuBarOnly") private var menuBarOnly = false
    @AppStorage("cookieSource") private var cookieSource = CookieSource.none.rawValue
    @AppStorage("cookieFilePath") private var cookieFilePath = ""

    private let iconChoices = [
        "cup.and.saucer.fill", "arrow.down.circle.fill",
        "film.fill", "square.and.arrow.down.fill", "play.circle.fill",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                section("Appearance") {
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 2), spacing: 8) {
                        ForEach(AppThemeStyle.allCases) { themeButton($0) }
                    }
                }

                section("Menu Bar") {
                    Toggle("Show icon in menu bar", isOn: $showMenuBarIcon)
                        .toggleStyle(.switch)
                        .disabled(menuBarOnly)
                        .onChange(of: showMenuBarIcon) { _, on in
                            // If turned off while in menu-bar-only mode it would
                            // strand the app; guard against that.
                            if !on && menuBarOnly { showMenuBarIcon = true }
                        }

                    Toggle("Menu bar only (hide Dock icon)", isOn: $menuBarOnly)
                        .toggleStyle(.switch)
                        .onChange(of: menuBarOnly) { _, on in
                            if on { showMenuBarIcon = true }
                            NSApp.setActivationPolicy(on ? .accessory : .regular)
                            if !on { NSApp.activate(ignoringOtherApps: true) }
                        }

                    if showMenuBarIcon {
                        Text("Menu bar icon")
                            .font(.caption2).foregroundStyle(theme.secondaryText)
                        HStack(spacing: 10) {
                            ForEach(iconChoices, id: \.self) { name in
                                Button { menuBarIcon = name } label: {
                                    Image(systemName: name)
                                        .font(.title3)
                                        .frame(width: 40, height: 40)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(menuBarIcon == name ? theme.accent.opacity(0.3) : .clear)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(menuBarIcon == name ? theme.accent : .white.opacity(0.12))
                                                )
                                        )
                                        .foregroundStyle(menuBarIcon == name ? theme.accent : theme.secondaryText)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Text("Mocha keeps running in the menu bar after you close the window. Use the menu bar icon to add links, download, or reopen the window.")
                        .font(.caption2)
                        .foregroundStyle(theme.secondaryText.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }

                section("Cookies") {
                    Picker("Read cookies from", selection: $cookieSource) {
                        ForEach(CookieSource.allCases) { Text($0.display).tag($0.rawValue) }
                    }
                    .pickerStyle(.menu)

                    if cookieSource == CookieSource.file.rawValue {
                        HStack(spacing: 8) {
                            Text(cookieFilePath.isEmpty
                                 ? "No file selected"
                                 : (cookieFilePath as NSString).lastPathComponent)
                                .font(.caption)
                                .foregroundStyle(cookieFilePath.isEmpty ? theme.secondaryText : theme.primaryText)
                                .lineLimit(1).truncationMode(.middle)
                            Spacer()
                            if !cookieFilePath.isEmpty {
                                Button { cookieFilePath = "" } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .buttonStyle(.plain).foregroundStyle(theme.secondaryText)
                            }
                            Button("Choose…") { chooseCookieFile() }
                                .controlSize(.small)
                        }
                        Text("Export a cookies.txt (Netscape format) from your browser — e.g. the “Get cookies.txt LOCALLY” extension — then select it here. This is the reliable way to use Helium, Orion or any browser yt-dlp can't read directly.")
                            .font(.caption2)
                            .foregroundStyle(theme.secondaryText.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Turn this on for age-restricted, private, members-only or region-locked videos that need you signed in. Safari may require Full Disk Access; Chromium browsers (incl. Brave) may prompt for Keychain access.")
                            .font(.caption2)
                            .foregroundStyle(theme.secondaryText.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                section("About") {
                    HStack {
                        Text("Mocha · v\(Updater.currentVersion)")
                            .font(.caption).foregroundStyle(theme.secondaryText)
                        Spacer()
                        Button {
                            Task { await updater.check() }
                        } label: {
                            if updater.state == .checking {
                                ProgressView().controlSize(.small)
                            } else {
                                Text("Check for Updates")
                            }
                        }
                        .buttonStyle(.bordered).controlSize(.small)
                        .disabled(updater.state == .checking)
                    }

                    updateStatus

                    Text("MIT open-source · powered by yt-dlp")
                        .font(.caption2).foregroundStyle(theme.secondaryText.opacity(0.7))
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private var updateStatus: some View {
        switch updater.state {
        case .upToDate:
            Label("You're on the latest version", systemImage: "checkmark.circle.fill")
                .font(.caption2).foregroundStyle(.green)
        case .available(let version, let url):
            HStack(spacing: 8) {
                Label("Version \(version) available", systemImage: "arrow.down.circle.fill")
                    .font(.caption2).foregroundStyle(theme.accent)
                Spacer()
                Button("Download") { NSWorkspace.shared.open(URL(string: url)!) }
                    .controlSize(.small).buttonStyle(.borderedProminent).tint(theme.accent)
            }
        case .failed(let msg):
            Label(msg, systemImage: "exclamationmark.triangle.fill")
                .font(.caption2).foregroundStyle(.orange).lineLimit(2)
        case .idle, .checking:
            EmptyView()
        }
    }

    // MARK: - Actions

    private func chooseCookieFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        if panel.runModal() == .OK, let url = panel.url {
            cookieFilePath = url.path
        }
    }

    // MARK: - Building blocks

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
                .textCase(.uppercase)
            content()
        }
        Divider().opacity(0.25)
    }

    @ViewBuilder
    private func themeButton(_ style: AppThemeStyle) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { theme.style = style }
        } label: {
            HStack {
                Circle().fill(style.swatch).frame(width: 12, height: 12)
                Text(style.rawValue).font(.subheadline)
                Spacer()
                if theme.style == style {
                    Image(systemName: "checkmark").font(.caption.weight(.bold))
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.style == style ? theme.accent.opacity(0.22) : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(theme.style == style ? theme.accent : .white.opacity(0.12), lineWidth: 1)
                    )
            )
            .foregroundStyle(theme.primaryText)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Updater

/// Checks GitHub Releases for a newer version and surfaces the download link.
@MainActor
final class Updater: ObservableObject {
    enum State: Equatable {
        case idle, checking, upToDate
        case available(version: String, url: String)
        case failed(String)
    }

    @Published var state: State = .idle

    static let currentVersion =
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    private let repo = "andlsac/mocha-downloader"

    func check() async {
        state = .checking
        let api = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!
        var req = URLRequest(url: api)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String else {
                state = .failed("Could not reach GitHub"); return
            }
            let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag

            // Prefer the .dmg asset; fall back to the release page.
            var link = json["html_url"] as? String ?? "https://github.com/\(repo)/releases/latest"
            if let assets = json["assets"] as? [[String: Any]],
               let dmg = assets.first(where: { ($0["name"] as? String)?.hasSuffix(".dmg") == true }),
               let url = dmg["browser_download_url"] as? String {
                link = url
            }

            state = Self.isNewer(latest, than: Self.currentVersion)
                ? .available(version: latest, url: link)
                : .upToDate
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
