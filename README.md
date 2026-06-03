# ☕ Mocha

A minimal, native macOS video downloader built on **yt-dlp** + **ffmpeg**.
SwiftUI · liquid-glass UI · menu bar app · MIT.

Downloader de vídeos nativo e minimalista para macOS, baseado em **yt-dlp** +
**ffmpeg**. SwiftUI · interface liquid-glass · vive na barra de menus · MIT.

---

## ✨ Features / Recursos

- 🎬 **Per-video quality picker** — real formats from yt-dlp (resolution, fps, codec, bitrate, size).
- 🎧 **Video or audio** — extract audio with detailed codec/bitrate info.
- 🍪 **Cookies** — Brave, Safari, Chrome, Chromium, Firefox, Edge, Opera, Vivaldi, or a `cookies.txt` file (Helium, Orion, anything).
- 🪟 **Menu bar app** — add links, download and manage the queue without opening the window.
- 🎨 **Themes** — System, Deep Ocean, Floral, Rare Jade — with frosted-glass vibrancy.
- ⚡ **Instant launch** — backend setup runs in the background, never blocks the UI.

PT-BR: seletor de qualidade por vídeo, vídeo ou áudio, cookies de vários
navegadores (ou arquivo), app de barra de menus, temas com vibrancy e
abertura instantânea.

---

## 📦 Install / Instalação

1. Download `Mocha-x.y.z.dmg` from [Releases](../../releases/latest).
2. Drag **Mocha** to Applications.
3. First launch downloads `yt-dlp` automatically. Install ffmpeg for merging:
   `brew install ffmpeg`.

> The app is **ad-hoc signed** (no paid Apple Developer ID). On first run:
> right-click → **Open**, or run `xattr -dr com.apple.quarantine /Applications/Mocha.app`.
> Verify the download with the checksum and SSH signature on the release page.

---

## 🔒 Security / Segurança

See [SECURITY.md](SECURITY.md). Built from a reverse-engineered MIT app with
the original's unsafe patterns fixed (no shell `curl`/command injection,
scheme validation, owner-only backend, TLS-enforced downloads).

## 🛠 Build

Open `Mocha.xcodeproj` in Xcode 16+ and build (macOS 14.6+). No dependencies.

## 📝 Credits

Downloading powered by [yt-dlp](https://github.com/yt-dlp/yt-dlp) and
[ffmpeg](https://ffmpeg.org). Inspired by the original *latte* app.
