import SwiftUI
import AppKit

enum AppThemeStyle: String, CaseIterable, Identifiable {
    case system    = "System"
    case deepOcean = "Deep Ocean"
    case floral    = "Floral"
    case rareJade  = "Rare Jade"
    var id: String { rawValue }

    var swatch: Color {
        switch self {
        case .system:    return Color(nsColor: .systemGray)
        case .deepOcean: return Color(red: 0.30, green: 0.62, blue: 1.00)
        case .floral:    return Color(red: 0.96, green: 0.46, blue: 0.66)
        case .rareJade:  return Color(red: 0.22, green: 0.85, blue: 0.55)
        }
    }
}

/// Drives both the accent color and the window tint. Persists across launches.
final class AppTheme: ObservableObject {
    @Published var style: AppThemeStyle {
        didSet { UserDefaults.standard.set(style.rawValue, forKey: "themeStyle") }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: "themeStyle") ?? AppThemeStyle.system.rawValue
        style = AppThemeStyle(rawValue: raw) ?? .system
    }

    /// Color used for buttons, progress, highlights.
    var accent: Color { style.swatch }

    /// Background wash layered over the vibrancy blur — this is what makes
    /// each theme visibly different (the previous version only changed accent).
    var tint: Color {
        switch style {
        case .system:    return .clear
        case .deepOcean: return Color(red: 0.03, green: 0.09, blue: 0.24)
        case .floral:    return Color(red: 0.20, green: 0.04, blue: 0.15)
        case .rareJade:  return Color(red: 0.02, green: 0.17, blue: 0.12)
        }
    }

    var tintOpacity: Double { style == .system ? 0 : 0.16 }

    var material: NSVisualEffectView.Material {
        style == .system ? .underWindowBackground : .hudWindow
    }

    /// How opaque the frosted material is. Lower = more transparent.
    /// Main window stays as before (fully frosted); only the popover is glassier.
    var windowGlassAlpha: CGFloat { 1.0 }
    var popoverGlassAlpha: CGFloat { 0.42 }

    /// Colored themes look best forced dark; System follows the OS.
    var colorScheme: ColorScheme? { style == .system ? nil : .dark }

    var isDark: Bool { style != .system }

    /// Foreground for primary text on the glass.
    var primaryText: Color { isDark ? .white : .primary }
    var secondaryText: Color { isDark ? Color.white.opacity(0.6) : Color(nsColor: .secondaryLabelColor) }
}
