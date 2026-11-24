import SwiftUI

enum Theme {
    static let ground = Color(light: 0xF5F6F9, dark: 0x071427)
    static let sheet = Color(light: 0xFFFFFF, dark: 0x0B1B31)
    static let ink = Color(light: 0x0B1B31, dark: 0xF3F7FD)
    static let body = Color(light: 0x33415C, dark: 0xC9D4E5)
    /// Only on `sheet`: on `ground` it falls below AA contrast, so use `body` there.
    static let muted = Color(light: 0x66738D, dark: 0x93A3BC)
    static let hairline = Color(light: 0xE7EAF0, dark: 0x1C3050)
    static let action = Color(light: 0x12315E, dark: 0x2CC3B6)
    static let onAction = Color(light: 0xFFFFFF, dark: 0x071427)
    static let teal = Color(light: 0x1FB3A6, dark: 0x2CC3B6)
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
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
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

struct PrimaryPillStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Theme.onAction)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(minHeight: Theme.minimumTarget)
            .background(Theme.action, in: .capsule)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(.capsule)
    }
}

struct SecondaryPillStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Theme.action)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(minHeight: Theme.minimumTarget)
            .background(Theme.sheet, in: .capsule)
            .overlay(Capsule().strokeBorder(Theme.hairline))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(.capsule)
    }
}
