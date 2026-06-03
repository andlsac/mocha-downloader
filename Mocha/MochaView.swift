import SwiftUI

struct MochaView: View {
    @EnvironmentObject var client: YTDLPClient
    @EnvironmentObject var theme: AppTheme

    @State private var urlText = ""
    @State private var downloadType: DownloadType = .video
    @State private var downloadSubtitles = false
    @State private var selectedTab: Tab = .downloads
    @State private var isFetchingInfo = false
    @State private var downloadFolder = FileManager.default
        .urls(for: .downloadsDirectory, in: .userDomainMask).first!

    private enum Tab: String { case downloads = "Downloads"; case config = "Config" }

    var body: some View {
        ZStack {
            VisualEffectView(material: theme.material, alpha: theme.windowGlassAlpha).ignoresSafeArea()
            theme.tint.opacity(theme.tintOpacity).ignoresSafeArea()

            VStack(spacing: 0) {
                titleBar
                if !client.isReady { backendBanner }
                if selectedTab == .downloads { downloadsTab } else { SettingsView() }
            }
        }
        .background(WindowConfigurator())
        .preferredColorScheme(theme.colorScheme)
        .tint(theme.accent)
        .onReceive(NotificationCenter.default.publisher(for: .addVideoURL)) { note in
            if let url = note.object as? String {
                urlText = url
                Task { await addCurrent() }
            }
        }
        .frame(minWidth: 480, idealWidth: 500, minHeight: 560, idealHeight: 620)
    }

    // MARK: - Title bar

    private var titleBar: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "cup.and.saucer.fill").foregroundStyle(theme.accent)
                Text("mocha")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.primaryText)
            }
            Spacer()
            HStack(spacing: 2) {
                tabButton(.downloads)
                tabButton(.config)
            }
            .padding(3)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func tabButton(_ tab: Tab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { selectedTab = tab }
        } label: {
            Text(tab.rawValue)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12).padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selectedTab == tab ? theme.accent.opacity(0.3) : .clear)
                )
                .foregroundStyle(selectedTab == tab ? theme.accent : theme.secondaryText)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: 96)
    }

    // MARK: - Backend banner

    @ViewBuilder
    private var backendBanner: some View {
        HStack(spacing: 8) {
            switch client.backend {
            case .installing:
                ProgressView().controlSize(.small)
                Text("Setting up backend… you can paste links meanwhile")
            case .failed(let msg):
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text(msg).lineLimit(1)
                Spacer()
                Button("Retry") { Task { await client.installBackend() } }
                    .controlSize(.small)
            default:
                ProgressView().controlSize(.small)
                Text("Checking environment…")
            }
        }
        .font(.caption)
        .foregroundStyle(theme.secondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Downloads tab

    private var downloadsTab: some View {
        VStack(spacing: 0) {
            inputArea
            Divider().opacity(0.3)
            if client.entries.isEmpty { emptyState } else { entryList }
            Divider().opacity(0.3)
            footer
        }
    }

    private var inputArea: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                TextField("Paste video link here", text: $urlText)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .onSubmit { Task { await addCurrent() } }
                Button {
                    Task { await addCurrent() }
                } label: {
                    Group {
                        if isFetchingInfo {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "plus").font(.headline)
                        }
                    }
                    .frame(width: 40, height: 40)
                    .background(theme.accent.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.white)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty || isFetchingInfo)
            }

            HStack(spacing: 12) {
                Picker("", selection: $downloadType) {
                    ForEach(DownloadType.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 150)

                if downloadType == .video {
                    Toggle("Subtitles", isOn: $downloadSubtitles).font(.caption)
                }
                Spacer()
                if !client.ffmpegAvailable {
                    Label("No ffmpeg", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2).foregroundStyle(.orange)
                }
            }
        }
        .padding(12)
    }

    private var entryList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(client.entries) { entry in
                    VideoRowView(
                        entry: entry,
                        theme: theme,
                        downloadType: downloadType,
                        onSelectFormat: { client.setFormat(id: entry.id, formatID: $0) },
                        onDownload: { startDownload(entry.id) },
                        onRemove: { client.removeEntry(id: entry.id) }
                    )
                }
            }
            .padding(12)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "arrow.down.circle")
                .font(.largeTitle).foregroundStyle(theme.secondaryText.opacity(0.5))
            Text("No videos selected")
                .font(.subheadline).foregroundStyle(theme.secondaryText)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }

    private var footer: some View {
        HStack {
            Button { chooseOutputFolder() } label: {
                Label(folderLabel, systemImage: "folder")
                    .font(.caption).foregroundStyle(theme.secondaryText)
                    .lineLimit(1).truncationMode(.middle)
                    .padding(.vertical, 4).padding(.horizontal, 6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer()
            if !client.entries.isEmpty {
                Button("Download All") { downloadAll() }
                    .buttonStyle(.borderedProminent).controlSize(.large).tint(theme.accent)
                    .disabled(!client.isReady)
                Button("Clear") { client.clearAll() }
                    .buttonStyle(.bordered).controlSize(.large)
            }
        }
        .padding(12)
    }

    // MARK: - Actions

    private func addCurrent() async {
        let link = urlText
        guard !link.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        urlText = ""
        isFetchingInfo = true
        await client.addEntry(urlString: link)
        isFetchingInfo = false
    }

    private func startDownload(_ id: UUID) {
        client.downloadEntry(
            id: id,
            downloadType: downloadType,
            downloadSubtitles: downloadSubtitles,
            outputFolder: downloadFolder
        )
    }

    private func downloadAll() {
        for entry in client.entries where !entry.completed && !entry.isDownloading {
            startDownload(entry.id)
        }
    }

    private func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.prompt = "Select"
        if panel.runModal() == .OK, let url = panel.url { downloadFolder = url }
    }

    private var folderLabel: String {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        return downloadFolder == downloads ? "Downloads" : downloadFolder.lastPathComponent
    }
}

// MARK: - Video row

struct VideoRowView: View {
    let entry: VideoEntry
    let theme: AppTheme
    let downloadType: DownloadType
    let onSelectFormat: (String?) -> Void
    let onDownload: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                ThumbnailView(url: entry.thumbnailURL)
                    .frame(width: 80, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.title.isEmpty ? entry.urlString : entry.title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(2)
                    statusLine
                }

                Spacer()

                HStack(spacing: 4) {
                    if !entry.completed && !entry.isDownloading {
                        iconButton("arrow.down.circle.fill", tint: theme.accent, action: onDownload)
                    }
                    iconButton("xmark.circle", tint: theme.secondaryText, action: onRemove)
                }
            }

            // Quality selector — shows the actual formats reported by yt-dlp.
            if !entry.isDownloading && !entry.completed {
                qualityMenu
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var statusLine: some View {
        if entry.isDownloading {
            ProgressView(value: entry.progress)
                .progressViewStyle(.linear).tint(theme.accent)
            Text(entry.progressText)
                .font(.caption2).foregroundStyle(theme.secondaryText).lineLimit(1)
        } else if let err = entry.error {
            Text(err).font(.caption2).foregroundStyle(.red).lineLimit(2)
        } else if entry.completed {
            Label("Completed", systemImage: "checkmark.circle.fill")
                .font(.caption2).foregroundStyle(.green)
        } else if !entry.progressText.isEmpty {
            Text(entry.progressText).font(.caption2).foregroundStyle(theme.secondaryText)
        }
    }

    @ViewBuilder
    private var qualityMenu: some View {
        let formats = entry.availableFormats(for: downloadType)
        if !formats.isEmpty {
            Menu {
                Button("Auto · best available") { onSelectFormat(nil) }
                Divider()
                ForEach(formats) { fmt in
                    Button(downloadType == .video ? fmt.videoLabel : fmt.audioLabel) {
                        onSelectFormat(fmt.id)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: downloadType == .video ? "slider.horizontal.3" : "waveform")
                        .font(.caption2)
                    Text(entry.selectionLabel(for: downloadType))
                        .font(.caption2)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 8))
                }
                .foregroundStyle(theme.secondaryText)
                .padding(.horizontal, 8).padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 7))
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
        }
    }

    @ViewBuilder
    private func iconButton(_ symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
