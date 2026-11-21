import SwiftUI
import CoreText

enum Palette {
    private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let value = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255, alpha: 1)
        })
    }
    static var background: Color { adaptive(0xFAF8F0, 0x090909) }
    static var sidebar: Color { adaptive(0xF3F0E7, 0x101010) }
    static var rail: Color { adaptive(0xEDEAE0, 0x080808) }
    static var surface: Color { adaptive(0xFFFFFF, 0x161616) }
    static var elevated: Color { adaptive(0xF5F2EA, 0x202020) }
    static var selected: Color { adaptive(0xE9E4D8, 0x292929) }
    static var border: Color { adaptive(0xDEDACF, 0x303030) }
    static var mint: Color { adaptive(0x5A497E, 0xA7F3D9) }
    static var text: Color { adaptive(0x302D27, 0xF2F3F5) }
    static var secondary: Color { adaptive(0x635F55, 0xB0B6C2) }
    static var muted: Color { adaptive(0x787266, 0x838B99) }
}

enum AppFont {
    static func register() {
        guard let url = Bundle.main.url(forResource: "Inter-Variable", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Inter-Regular", size: size).weight(weight)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: 1)
    }
}

/// Shared mascot artwork used throughout the native app.
struct OutloudMark: View {
    var color: Color = Palette.mint
    var body: some View {
        Image("OutloudMascot").resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 7)).accessibilityLabel("Outloud")
    }
}

struct AppButtonStyle: ButtonStyle {
    var primary = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(AppFont.ui(13, weight: .medium))
            .padding(.horizontal, 16).padding(.vertical, 10)
            .foregroundStyle(primary ? Palette.background : Palette.text)
            .background(primary ? Palette.text : Palette.elevated, in: Capsule())
            .overlay(Capsule().strokeBorder(primary ? Color.white.opacity(0.12) : Palette.border.opacity(0.65)))
            .shadow(color: .black.opacity(primary && enabled ? 0.08 : 0), radius: 3, y: 2)
            .opacity(enabled ? (configuration.isPressed ? 0.78 : 1) : 0.4)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct IconButton: View {
    let symbol: String
    let label: String
    var active = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 13, weight: .medium))
                .frame(width: 30, height: 30)
                .foregroundStyle(active ? Palette.mint : Palette.secondary)
                .background(active ? Palette.mint.opacity(0.1) : Palette.surface, in: RoundedRectangle(cornerRadius: 7))
        }.buttonStyle(.plain).help(label).accessibilityLabel(label)
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(.system(size: 10, weight: .semibold))
            .tracking(0.7).foregroundStyle(Palette.muted)
    }
}

struct EmptyWorkspaceView: View {
    let symbol: String
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol).font(.system(size: 27, weight: .light))
                .foregroundStyle(Palette.mint).frame(width: 62, height: 62)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18))
            Text(title).font(.system(size: 22, weight: .semibold))
            Text(message).font(.system(size: 13)).foregroundStyle(Palette.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 350)
            Button(actionTitle, action: action).buttonStyle(AppButtonStyle(primary: true))
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(40)
    }
}

struct SourceAvatar: View {
    let target: WatchTarget
    var size: CGFloat = 24
    var body: some View {
        Group {
            if let data = target.avatarData, let image = NSImage(data: data) {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: target.profileURL == nil ? "number" : "person.crop.circle")
                    .font(.system(size: size * 0.58, weight: .regular)).foregroundStyle(Palette.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity).background(Palette.selected.opacity(0.6))
            }
        }.frame(width: size, height: size).clipShape(Circle())
            .overlay(alignment: .bottomTrailing) {
                PlatformBadge(platform: target.platform, size: max(12, size * 0.47))
                    .padding(1).background(Color.white, in: RoundedRectangle(cornerRadius: 4))
                    .shadow(color: .black.opacity(0.18), radius: 2, y: 1).offset(x: 4, y: 3)
            }.accessibilityLabel(target.displayName)
    }
}
