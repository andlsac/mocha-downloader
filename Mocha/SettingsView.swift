import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var theme: AppTheme
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
                        Text("Mocha · v0.1.0")
                            .font(.caption).foregroundStyle(theme.secondaryText)
                        Spacer()
                        Button("Check for Updates") {
                            NSWorkspace.shared.open(
                                URL(string: "https://github.com/your-handle/mocha/releases/latest")!
                            )
                        }
                        .buttonStyle(.bordered).controlSize(.small)
                    }
                    Text("MIT open-source · powered by yt-dlp")
                        .font(.caption2).foregroundStyle(theme.secondaryText.opacity(0.7))
                }
            }
            .padding()
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
