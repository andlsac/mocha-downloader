import Foundation

enum DownloadType: String, CaseIterable, Identifiable {
    case video = "Video"
    case audio = "Audio"
    var id: String { rawValue }
}

/// Where to read login cookies from — needed for age-restricted, private,
/// members-only or region-locked videos. yt-dlp does NOT read cookies on its own.
///
/// Browser cases map to `--cookies-from-browser`. `file` maps to `--cookies`
/// with a Netscape cookies.txt, which is the only reliable route for browsers
/// yt-dlp can't read directly (Helium, Orion, …).
enum CookieSource: String, CaseIterable, Identifiable {
    case none
    case brave
    case safari
    case chrome
    case chromium
    case firefox
    case edge
    case opera
    case vivaldi
    case file       // cookies.txt — covers Helium, Orion, anything else

    var id: String { rawValue }

    var display: String {
        switch self {
        case .none:     return "None"
        case .brave:    return "Brave"
        case .safari:   return "Safari"
        case .chrome:   return "Chrome"
        case .chromium: return "Chromium"
        case .firefox:  return "Firefox"
        case .edge:     return "Edge"
        case .opera:    return "Opera"
        case .vivaldi:  return "Vivaldi"
        case .file:     return "Cookies file (Helium, Orion…)"
        }
    }

    /// Value for `--cookies-from-browser`; nil for `none` and `file`.
    var browserArg: String? {
        switch self {
        case .none, .file: return nil
        default:           return rawValue   // matches yt-dlp's browser names
        }
    }
}

/// One selectable quality reported by yt-dlp's `formats` array.
struct MediaFormat: Identifiable, Equatable {
    let id: String          // yt-dlp format_id
    let ext: String
    let height: Int?
    let fps: Double?
    let vcodec: String?
    let acodec: String?
    let filesize: Int?      // bytes (exact or approx)
    let tbr: Double?        // total bitrate kbps
    let abr: Double?        // audio bitrate kbps
    let note: String?

    var hasVideo: Bool { let v = vcodec ?? "none"; return v != "none" && !v.isEmpty }
    var hasAudio: Bool { let a = acodec ?? "none"; return a != "none" && !a.isEmpty }
    var isAudioOnly: Bool { !hasVideo && hasAudio }

    var sizeText: String? {
        guard let filesize, filesize > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(filesize), countStyle: .file)
    }

    /// e.g. "1080p · 60fps · H.264 · mp4 · 45.2 MB"
    var videoLabel: String {
        var parts: [String] = []
        if let height { parts.append("\(height)p") }
        if let fps, fps > 0 { parts.append("\(Int(fps.rounded()))fps") }
        let vc = Self.shortCodec(vcodec); if !vc.isEmpty { parts.append(vc) }
        parts.append(ext)
        if let sizeText { parts.append(sizeText) }
        return parts.joined(separator: " · ")
    }

    /// e.g. "Opus · 160 kbps · webm · 3.1 MB"
    var audioLabel: String {
        var parts: [String] = []
        let ac = Self.shortCodec(acodec); if !ac.isEmpty { parts.append(ac) }
        if let abr, abr > 0 { parts.append("\(Int(abr.rounded())) kbps") }
        else if let tbr, tbr > 0 { parts.append("\(Int(tbr.rounded())) kbps") }
        parts.append(ext)
        if let sizeText { parts.append(sizeText) }
        return parts.joined(separator: " · ")
    }

    static func shortCodec(_ c: String?) -> String {
        guard let c, c != "none", !c.isEmpty else { return "" }
        let l = c.lowercased()
        if l.hasPrefix("avc1") || l.hasPrefix("h264") { return "H.264" }
        if l.hasPrefix("hev1") || l.hasPrefix("hvc1") || l.contains("h265") { return "H.265" }
        if l.hasPrefix("vp9") || l.hasPrefix("vp09") { return "VP9" }
        if l.hasPrefix("av01") { return "AV1" }
        if l.hasPrefix("mp4a") { return "AAC" }
        if l.hasPrefix("opus") { return "Opus" }
        if l.hasPrefix("vorbis") { return "Vorbis" }
        if l.hasPrefix("flac") { return "FLAC" }
        if l.hasPrefix("mp3") || l.contains("mpeg") { return "MP3" }
        if l.hasPrefix("ec-3") || l.hasPrefix("ac-3") { return "AC-3" }
        return c
    }
}

struct VideoEntry: Identifiable, Equatable {
    let id = UUID()
    var urlString: String
    var title: String = ""
    var thumbnailURL: URL?
    var formats: [MediaFormat] = []
    var selectedFormatID: String?       // nil = Auto (best)
    var isDownloading = false
    var progress: Double = 0
    var progressText: String = ""
    var error: String?
    var completed = false

    func availableFormats(for type: DownloadType) -> [MediaFormat] {
        switch type {
        case .video:
            return formats.filter { $0.hasVideo }
                .sorted { ($0.height ?? 0, $0.tbr ?? 0) > ($1.height ?? 0, $1.tbr ?? 0) }
        case .audio:
            return formats.filter { $0.isAudioOnly }
                .sorted { ($0.abr ?? $0.tbr ?? 0) > ($1.abr ?? $1.tbr ?? 0) }
        }
    }

    func selectionLabel(for type: DownloadType) -> String {
        if let fid = selectedFormatID, let f = formats.first(where: { $0.id == fid }) {
            return type == .video ? f.videoLabel : f.audioLabel
        }
        return "Auto · best available"
    }
}
