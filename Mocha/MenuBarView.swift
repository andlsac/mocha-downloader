import SwiftUI
import AppKit

/// Full-featured popover shown from the menu bar icon — Mocha works entirely
/// from here without ever opening the main window.
struct MenuBarView: View {
    @EnvironmentObject var client: YTDLPClient
    @EnvironmentObject var theme: AppTheme
    @Environment(\.openWindow) private var openWindow

    @State private var urlText = ""
    @State private var type: DownloadType = .video

    private var downloads: URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    }

    var body: some View {
        ZStack {
            // Extra-glassy frosted background — more transparent than the main window.
            VisualEffectView(material: theme.material, alpha: theme.popoverGlassAlpha).ignoresSafeArea()
            theme.tint.opacity(theme.tintOpacity * 0.7).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 10) {
                header
                Divider()
                addRow
                if !client.entries.isEmpty {
                    queueList
                    Divider()
                }
                footer
            }
            .padding(12)
        }
        .frame(width: 300)
        .background(TransparentWindow())
        .preferredColorScheme(theme.colorScheme)
        .tint(theme.accent)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "cup.and.saucer.fill").foregroundStyle(theme.accent)
            Text("Mocha").font(.headline)
            Spacer()
            HStack(spacing: 5) {
                Circle()
                    .fill(client.isReady ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                Text(client.isReady ? "Ready" : "Setting up…")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Add row

    private var addRow: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                TextField("Paste link…", text: $urlText)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .padding(7)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 7))
                    .onSubmit(add)
                Button("Paste") { pasteFromClipboard() }
                    .controlSize(.small)
            }
            HStack(spacing: 8) {
                Picker("", selection: $type) {
                    ForEach(DownloadType.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().controlSize(.small)

                Button(action: add) {
                    Label("Add", systemImage: "plus")
                        .font(.caption.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(theme.accent.opacity(0.9), in: RoundedRectangle(cornerRadius: 7))
                        .foregroundStyle(.white)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!client.isReady || urlText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    // MARK: - Queue

    private var queueList: some View {
        VStack(spacing: 6) {
            ForEach(client.entries.prefix(6)) { entry in
                HStack(spacing: 8) {
                    statusIcon(for: entry)
                    Text(entry.title.isEmpty ? entry.urlString : entry.title)
                        .font(.caption2).lineLimit(1)
                    Spacer()
                    if entry.isDownloading {
                        Text("\(Int(entry.progress * 100))%")
                            .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    } else if !entry.completed {
                        Button { download(entry.id) } label: {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(theme.accent)
                                .frame(width: 22, height: 22)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!client.isReady)
                    }
                    Button { client.removeEntry(id: entry.id) } label: {
                        Image(systemName: "xmark")
                            .font(.caption2).foregroundStyle(.secondary)
                            .frame(width: 18, height: 18)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            if client.entries.count > 6 {
                Text("+\(client.entries.count - 6) more")
                    .font(.caption2).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func statusIcon(for entry: VideoEntry) -> some View {
        if entry.completed {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.caption2)
        } else if entry.error != nil {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red).font(.caption2)
        } else if entry.isDownloading {
            ProgressView().controlSize(.mini)
        } else {
            Image(systemName: "circle").foregroundStyle(.secondary).font(.caption2)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 4) {
            menuButton("Open main window", icon: "macwindow") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
            menuButton("Quit Mocha", icon: "power", role: .destructive) {
                NSApp.terminate(nil)
            }
        }
    }

    @ViewBuilder
    private func menuButton(_ title: String, icon: String, role: ButtonRole? = nil,
                            action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: icon)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 5).padding(.horizontal, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func add() {
        let link = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !link.isEmpty else { return }
        urlText = ""
        Task { await client.addEntry(urlString: link) }
    }

    private func pasteFromClipboard() {
        if let s = NSPasteboard.general.string(forType: .string) { urlText = s }
    }

    private func download(_ id: UUID) {
        client.downloadEntry(
            id: id,
            downloadType: type,
            downloadSubtitles: false,
            outputFolder: downloads
        )
    }
}
