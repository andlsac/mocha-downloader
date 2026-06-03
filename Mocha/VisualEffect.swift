import SwiftUI
import AppKit

/// Translucent vibrancy background (frosted glass) used behind every window.
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    /// < 1 makes the frosted material itself see-through, letting the desktop
    /// bleed through for a much glassier / "liquid glass" look.
    var alpha: CGFloat = 1

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = true
        view.alphaValue = alpha
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
        view.alphaValue = alpha
    }
}

/// Minimal helper that just clears the hosting window's background so a
/// `behindWindow` vibrancy view can blur what's behind it. Used by the
/// menu bar popover, which has no titlebar to configure.
struct TransparentWindow: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            guard let window = view?.window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// Grabs the hosting NSWindow once and makes it transparent so the vibrancy
/// behind the content shows through. Runs once, costs nothing afterwards.
struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            guard let window = view?.window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.styleMask.insert(.fullSizeContentView)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
