import Foundation
import Combine

enum BackendState: Equatable {
    case unknown
    case installing(Double?)   // nil = indeterminate
    case ready
    case failed(String)
}

@MainActor
final class YTDLPClient: ObservableObject {
    @Published var backend: BackendState = .unknown
    @Published var ffmpegAvailable = false
    @Published var entries: [VideoEntry] = []

    private(set) var ytdlpPath: String?
    private let fileManager = FileManager.default
    private var runningProcesses: [UUID: Process] = [:]

    var isReady: Bool { backend == .ready }

    private var supportDir: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Mocha", isDirectory: true)
    }
    private var ytdlpBin: URL { supportDir.appendingPathComponent("yt-dlp") }

    // MARK: - Bootstrap (fast, never blocks the UI)

    /// Called once on launch. Returns almost immediately:
    /// if the backend is already on disk we mark ready optimistically and only
    /// verify quietly in the background, so the window opens instantly.
    func bootstrap() async {
        try? fileManager.createDirectory(
            at: supportDir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        refreshFFmpeg()

        if fileManager.fileExists(atPath: ytdlpBin.path) {
            ytdlpPath = ytdlpBin.path
            backend = .ready
            // Quiet background sanity check — only reinstall if actually broken.
            Task.detached(priority: .background) { [bin = ytdlpBin] in
                let ok = await Self.run(executable: bin, args: ["--version"]).status == 0
                if !ok { await self.installBackend() }
            }
        } else {
            await installBackend()
        }
    }

    private func refreshFFmpeg() {
        let paths = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg",
                     "/usr/bin/ffmpeg", "/bin/ffmpeg"]
        ffmpegAvailable = paths.contains { fileManager.fileExists(atPath: $0) }
    }

    func installBackend() async {
        backend = .installing(nil)
        let src = URL(string: "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos")!
        let tmp = fileManager.temporaryDirectory.appendingPathComponent("yt-dlp-\(UUID().uuidString)")
        do {
            let (downloaded, response) = try await URLSession(configuration: .ephemeral).download(from: src)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                backend = .failed("Download failed"); return
            }
            try? fileManager.removeItem(at: tmp)
            try fileManager.moveItem(at: downloaded, to: tmp)
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: tmp.path)
            if fileManager.fileExists(atPath: ytdlpBin.path) { try fileManager.removeItem(at: ytdlpBin) }
            try fileManager.moveItem(at: tmp, to: ytdlpBin)

            if await Self.run(executable: ytdlpBin, args: ["--version"]).status == 0 {
                ytdlpPath = ytdlpBin.path
                backend = .ready
            } else {
                backend = .failed("Backend verification failed")
            }
        } catch {
            try? fileManager.removeItem(at: tmp)
            backend = .failed(error.localizedDescription)
        }
    }

    // MARK: - Entry management

    func addEntry(urlString: String) async {
        let raw = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = URL(string: raw),
              parsed.scheme == "https" || parsed.scheme == "http" else { return }
        guard !entries.contains(where: { $0.urlString == raw }) else { return }

        var entry = VideoEntry(urlString: raw)
        entry.progressText = "Fetching info…"
        entries.append(entry)
        let id = entry.id

        guard let bin = ytdlpPath else {
            update(id: id) { $0.progressText = ""; $0.error = "Backend not ready yet" }
            return
        }

        let result = await Self.run(
            executable: URL(fileURLWithPath: bin),
            args: Self.cookieArgs() + ["--dump-json", "--no-playlist", parsed.absoluteString]
        )
        guard result.status == 0,
              let json = try? JSONSerialization.jsonObject(with: result.output) as? [String: Any] else {
            update(id: id) { $0.progressText = ""; $0.error = "Could not fetch info" }
            return
        }
        let title = json["title"] as? String ?? ""
        let thumb = (json["thumbnail"] as? String).flatMap(URL.init)
        let formats = Self.parseFormats(json["formats"] as? [[String: Any]] ?? [])
        update(id: id) {
            $0.title = title
            $0.thumbnailURL = thumb
            $0.formats = formats
            $0.progressText = ""
        }
    }

    /// Build a quality list from yt-dlp's raw `formats` array.
    private static func parseFormats(_ raw: [[String: Any]]) -> [MediaFormat] {
        raw.compactMap { f in
            guard let id = f["format_id"] as? String else { return nil }
            let size = (f["filesize"] as? Int) ?? (f["filesize_approx"] as? Int)
            return MediaFormat(
                id: id,
                ext: f["ext"] as? String ?? "",
                height: f["height"] as? Int,
                fps: (f["fps"] as? NSNumber)?.doubleValue,
                vcodec: f["vcodec"] as? String,
                acodec: f["acodec"] as? String,
                filesize: size,
                tbr: (f["tbr"] as? NSNumber)?.doubleValue,
                abr: (f["abr"] as? NSNumber)?.doubleValue,
                note: f["format_note"] as? String
            )
        }
    }

    func setFormat(id: UUID, formatID: String?) {
        update(id: id) { $0.selectedFormatID = formatID }
    }

    func removeEntry(id: UUID) {
        runningProcesses[id]?.terminate()
        runningProcesses[id] = nil
        entries.removeAll { $0.id == id }
    }

    func clearAll() {
        runningProcesses.values.forEach { $0.terminate() }
        runningProcesses.removeAll()
        entries.removeAll()
    }

    // MARK: - Download (streams progress; never blocks main thread)

    func downloadEntry(
        id: UUID,
        downloadType: DownloadType,
        downloadSubtitles: Bool,
        outputFolder: URL
    ) {
        guard let bin = ytdlpPath,
              let entry = entries.first(where: { $0.id == id }),
              let parsed = URL(string: entry.urlString),
              parsed.scheme == "https" || parsed.scheme == "http" else { return }

        update(id: id) { $0.isDownloading = true; $0.error = nil; $0.progress = 0 }

        var args = Self.cookieArgs() + Self.formatArgs(for: entry, type: downloadType)
        if downloadType == .video && downloadSubtitles {
            args += ["--write-sub", "--write-auto-sub", "--sub-lang", "en"]
        }
        args += [
            "--progress", "--newline", "--no-playlist",
            "-o", outputFolder.appendingPathComponent("%(title)s.%(ext)s").path,
            parsed.absoluteString,
        ]

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: bin)
        proc.arguments = args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let line = String(data: data, encoding: .utf8) else { return }
            let pct = Self.parsePercent(from: line)
            let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
            Task { @MainActor in
                self.update(id: id) { e in
                    if let pct { e.progress = pct }
                    if !text.isEmpty { e.progressText = text }
                }
            }
        }
        proc.terminationHandler = { p in
            let status = p.terminationStatus
            Task { @MainActor in
                p.standardOutput.flatMap { ($0 as? Pipe)?.fileHandleForReading.readabilityHandler = nil }
                self.runningProcesses[id] = nil
                self.update(id: id) { e in
                    e.isDownloading = false
                    if status == 0 { e.completed = true; e.progress = 1; e.progressText = "" }
                    else { e.error = "Download failed (\(status))" }
                }
            }
        }

        do {
            try proc.run()
            runningProcesses[id] = proc
        } catch {
            update(id: id) { $0.isDownloading = false; $0.error = error.localizedDescription }
        }
    }

    // MARK: - Off-main-thread process runner

    /// Runs a process on a background queue and awaits its result without ever
    /// blocking the main actor. This is the core fix for the launch hangs.
    nonisolated static func run(executable: URL, args: [String]) async -> (status: Int32, output: Data) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let proc = Process()
                proc.executableURL = executable
                proc.arguments = args
                let pipe = Pipe()
                proc.standardOutput = pipe
                proc.standardError = Pipe()
                do { try proc.run() }
                catch { continuation.resume(returning: (-1, Data())); return }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                proc.waitUntilExit()
                continuation.resume(returning: (proc.terminationStatus, data))
            }
        }
    }

    // MARK: - Helpers

    private func update(id: UUID, apply: (inout VideoEntry) -> Void) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        apply(&entries[idx])
    }

    /// Reads the user's cookie preference and turns it into yt-dlp flags.
    static func cookieArgs() -> [String] {
        let raw = UserDefaults.standard.string(forKey: "cookieSource") ?? CookieSource.none.rawValue
        guard let source = CookieSource(rawValue: raw) else { return [] }
        if source == .file {
            let path = UserDefaults.standard.string(forKey: "cookieFilePath") ?? ""
            return path.isEmpty ? [] : ["--cookies", path]
        }
        if let browser = source.browserArg {
            return ["--cookies-from-browser", browser]
        }
        return []
    }

    /// Maps the entry's chosen quality to a yt-dlp `-f` selector.
    /// Video-only formats are auto-merged with the best audio track.
    static func formatArgs(for entry: VideoEntry, type: DownloadType) -> [String] {
        if let fid = entry.selectedFormatID,
           let fmt = entry.formats.first(where: { $0.id == fid }) {
            switch type {
            case .video:
                return fmt.hasAudio ? ["-f", fid] : ["-f", "\(fid)+bestaudio/\(fid)"]
            case .audio:
                return ["-f", fid]
            }
        }
        // Auto
        switch type {
        case .video: return ["-f", "bestvideo+bestaudio/best"]
        case .audio: return ["-x", "--audio-format", "best", "-f", "bestaudio/best"]
        }
    }

    nonisolated static func parsePercent(from line: String) -> Double? {
        guard line.contains("[download]"),
              let range = line.range(of: #"\d+\.?\d*%"#, options: .regularExpression) else { return nil }
        return Double(line[range].dropLast()).map { $0 / 100 }
    }
}
