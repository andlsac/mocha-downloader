import SwiftUI

struct ThumbnailView: View {
    let url: URL?
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        Image(systemName: "film")
                            .foregroundStyle(.secondary)
                    )
            }
        }
        .task(id: url) {
            guard let url else { image = nil; return }
            image = await loadImage(from: url)
        }
    }

    private func loadImage(from url: URL) async -> NSImage? {
        // SECURITY: validate host before fetching thumbnail
        guard url.host != nil,
              url.scheme == "https" || url.scheme == "http" else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return NSImage(data: data)
    }
}
