import SwiftUI

enum Theme {
    static let ground = Color(light: 0xF5F6F9, dark: 0x071427)
    static let sheet = Color(light: 0xFFFFFF, dark: 0x0B1B31)
    static let ink = Color(light: 0x0B1B31, dark: 0xF3F7FD)
    static let body = Color(light: 0x33415C, dark: 0xC9D4E5)
    /// Only on `sheet`: on `ground` it falls below AA contrast, so use `body` there.
    static let muted = Color(light: 0x66738D, dark: 0x93A3BC)
    /// With increased contrast, at least 3:1 against `sheet` and `ground` in both modes.
    static let hairline = Color(light: 0xE7EAF0, dark: 0x1C3050, highContrastLight: 0x66738D, highContrastDark: 0x6F84A6)
    static let selection = Color(light: 0x0F8F85, dark: 0x0F8F85, highContrastLight: 0x075F59, highContrastDark: 0x2CC3B6)
    static let action = Color(light: 0x12315E, dark: 0x2CC3B6)
    static let onAction = Color(light: 0xFFFFFF, dark: 0x071427)
    /// A fill: at least 3:1 under a white glyph and against `sheet` in both modes.
    static let teal = Color(light: 0x0F8F85, dark: 0x0F8F85)
    static let nearestPin = Color(light: 0x12315E, dark: 0x3B6FC4)
    static let originFill = Color(light: 0x12315E, dark: 0xFFFFFF)
    static let originRing = Color(light: 0xFFFFFF, dark: 0x071427)
    static let tealText = Color(light: 0x0B7C74, dark: 0x2CC3B6)
    static let amber = Color(light: 0x97660B, dark: 0xF0B84A)
    static let error = Color(light: 0xB42318, dark: 0xFF8A7E)

    /// Used in the hero only.
    static let heroGradient = LinearGradient(
        colors: [Color(light: 0xFFE3D1, dark: 0x3A2A2E), Color(light: 0xD6E6FA, dark: 0x10294C)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardRadius: CGFloat = 16
    static let minimumTarget: CGFloat = 44
}

extension Color {
    init(light: UInt32, dark: UInt32, highContrastLight: UInt32? = nil, highContrastDark: UInt32? = nil) {
        self.init(uiColor: UIColor { traits in
            let isHighContrast = traits.accessibilityContrast == .high
            return UIColor(rgb: traits.userInterfaceStyle == .dark
                ? (isHighContrast ? highContrastDark : nil) ?? dark
                : (isHighContrast ? highContrastLight : nil) ?? light)
        })
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

struct PillStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
    }

    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(kind == .primary ? Theme.onAction : Theme.action)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(minHeight: Theme.minimumTarget)
            .background(kind == .primary ? Theme.action : Theme.sheet, in: .capsule)
            .overlay {
                if kind == .secondary { Capsule().strokeBorder(Theme.hairline) }
            }
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(.capsule)
    }
}

extension ButtonStyle where Self == PillStyle {
    static var primaryPill: PillStyle { PillStyle(kind: .primary) }
    static var secondaryPill: PillStyle { PillStyle(kind: .secondary) }
}

/// Looks like a link in text, with a full-size target.
struct TextLinkStyle: ButtonStyle {
    var alignment = Alignment.leading

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .underline()
            .foregroundStyle(Theme.action)
            .multilineTextAlignment(.leading)
            .frame(minWidth: Theme.minimumTarget, minHeight: Theme.minimumTarget, alignment: alignment)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(.rect)
    }
}

extension ButtonStyle where Self == TextLinkStyle {
    static var textLink: TextLinkStyle { TextLinkStyle() }
}
