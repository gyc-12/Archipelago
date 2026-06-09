import SwiftUI

/// Design tokens derived from DESIGN.md for the Archipelago group-chat UI.
/// The Island overlay has a dark background, so we use light-on-dark colors:
/// "on-dark" text tokens reference the light end of the palette, while
/// surface tokens provide subtle contrast layers within the dark panel.
enum ArchipelagoDesign {
    // MARK: - Colors (light palette from DESIGN.md)

    static let canvas = Color(red: 0xfd / 255.0, green: 0xfc / 255.0, blue: 0xfc / 255.0)
    static let ink = Color(red: 0x20 / 255.0, green: 0x1d / 255.0, blue: 0x1d / 255.0)
    static let inkDeep = Color(red: 0x0f / 255.0, green: 0x00 / 255.0, blue: 0x00 / 255.0)
    static let body = Color(red: 0x42 / 255.0, green: 0x42 / 255.0, blue: 0x45 / 255.0)
    static let mute = Color(red: 0x64 / 255.0, green: 0x62 / 255.0, blue: 0x62 / 255.0)
    static let ash = Color(red: 0x9a / 255.0, green: 0x98 / 255.0, blue: 0x98 / 255.0)
    static let surfaceSoft = Color(red: 0xf8 / 255.0, green: 0xf7 / 255.0, blue: 0xf7 / 255.0)
    static let surfaceCard = Color(red: 0xf1 / 255.0, green: 0xee / 255.0, blue: 0xee / 255.0)
    static let surfaceDark = Color(red: 0x20 / 255.0, green: 0x1d / 255.0, blue: 0x1d / 255.0)
    static let hairline = Color(red: 0x0f / 255.0, green: 0x00 / 255.0, blue: 0x00 / 255.0).opacity(0.12)

    // MARK: - Semantic Colors

    static let accent = Color(red: 0x00 / 255.0, green: 0x7a / 255.0, blue: 0xff / 255.0)
    static let success = Color(red: 0x30 / 255.0, green: 0xd1 / 255.0, blue: 0x58 / 255.0)
    static let warning = Color(red: 0xff / 255.0, green: 0x9f / 255.0, blue: 0x0a / 255.0)
    static let danger = Color(red: 0xff / 255.0, green: 0x3b / 255.0, blue: 0x30 / 255.0)

    static func agentColor(_ agentType: ArchipelagoAgentType) -> Color {
        switch agentType {
        case .claudeCode: return Color(red: 0xd9 / 255.0, green: 0x77 / 255.0, blue: 0x57 / 255.0)
        case .codex: return Color(red: 0x7a / 255.0, green: 0x9d / 255.0, blue: 0xff / 255.0)
        case .openCode: return Color(red: 0.48, green: 0.42, blue: 0.96)
        case .gemini: return Color(red: 0x31 / 255.0, green: 0x86 / 255.0, blue: 0xff / 255.0)
        case .openClaw: return Color(red: 0xff / 255.0, green: 0x4d / 255.0, blue: 0x4d / 255.0)
        case .cline: return Color(red: 0.55, green: 0.75, blue: 0.35)
        case .unknown: return ash
        }
    }

    // MARK: - On-Dark tokens (for use in the dark overlay panel)

    /// Primary text on dark background
    static let onDarkPrimary = canvas
    /// Secondary text on dark background
    static let onDarkSecondary = canvas.opacity(0.7)
    /// Tertiary/muted text on dark background
    static let onDarkTertiary = canvas.opacity(0.4)
    /// Subtle surface within the dark panel
    static let onDarkSurface = Color.white.opacity(0.055)
    /// Subtle elevated surface within the dark panel
    static let onDarkSurfaceElevated = Color.white.opacity(0.075)
    /// Subtle border within the dark panel
    static let onDarkBorder = Color.white.opacity(0.10)

    // MARK: - Typography (SF Pro / system text, per DESIGN.md)

    static func bodyFont() -> Font {
        .system(size: 16, weight: .regular, design: .default)
    }

    static func headingFont() -> Font {
        .system(size: 16, weight: .semibold, design: .default)
    }

    static func captionFont() -> Font {
        .system(size: 14, weight: .regular, design: .default)
    }

    static func buttonFont() -> Font {
        .system(size: 16, weight: .medium, design: .default)
    }

    /// Scaled variant for the compact row context (Island overlay uses smaller sizes)
    static func rowTitleFont() -> Font {
        .system(size: 13, weight: .semibold, design: .default)
    }

    static func rowCaptionFont() -> Font {
        .system(size: 11, weight: .regular, design: .default)
    }

    static func sectionHeaderFont() -> Font {
        .system(size: 14, weight: .semibold, design: .default)
    }

    static func badgeFont() -> Font {
        .system(size: 10, weight: .semibold, design: .default)
    }

    // MARK: - Shape

    /// Interactive elements (buttons, badges, chips)
    static let radiusSm: CGFloat = 8
    /// Containers (no rounding per DESIGN.md)
    static let radiusNone: CGFloat = 0

    // MARK: - Spacing

    static let spacingSm: CGFloat = 8
    static let spacingMd: CGFloat = 12
    static let spacingLg: CGFloat = 16
    static let spacingXl: CGFloat = 24
}

// MARK: - AgentDisplayStatus Color Mapping

extension AgentDisplayStatus {
    /// The status dot color for this display status, using ArchipelagoDesign tokens.
    var dotColor: Color {
        switch self {
        case .working: return ArchipelagoDesign.success
        case .blocked: return ArchipelagoDesign.warning
        case .idle: return ArchipelagoDesign.ash
        case .offline: return ArchipelagoDesign.danger
        }
    }
}
