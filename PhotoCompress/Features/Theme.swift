import SwiftUI
import UIKit

extension Color {
    /// Fill for primary buttons; dark enough for white text in both appearances.
    static let brandFill = Color(red: 0x24 / 255, green: 0x47 / 255, blue: 0xD6 / 255)
    static let brandText = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.62, green: 0.72, blue: 1, alpha: 1)
            : UIColor(red: 0x24 / 255, green: 0x47 / 255, blue: 0xD6 / 255, alpha: 1)
    })
    static let success = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.36, green: 0.80, blue: 0.56, alpha: 1)
            : UIColor(red: 0x1B / 255, green: 0x7A / 255, blue: 0x4B / 255, alpha: 1)
    })
    static let failure = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1, green: 0.55, blue: 0.48, alpha: 1)
            : UIColor(red: 0xA3 / 255, green: 0x2A / 255, blue: 0x1D / 255, alpha: 1)
    })
    static let ground = Color(.systemGroupedBackground)
    static let card = Color(.secondarySystemGroupedBackground)
}

struct PrimaryButtonStyle: ButtonStyle {
    var height: CGFloat = 60
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(height >= 56 ? .title3.weight(.bold) : .body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(Color.brandFill.opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4), in: .rect(cornerRadius: height >= 56 ? 16 : 12))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var height: CGFloat = 56
    var tint = Color.primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(height >= 56 ? .title3.weight(.semibold) : .body.weight(.semibold))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(Color.card.opacity(configuration.isPressed ? 0.6 : 1), in: .rect(cornerRadius: height >= 56 ? 16 : 12))
            .overlay(RoundedRectangle(cornerRadius: height >= 56 ? 16 : 12).stroke(Color(.separator)))
    }
}

extension View {
    func card() -> some View {
        background(Color.card, in: .rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator).opacity(0.6)))
    }
}

extension Int {
    /// Localized file size, e.g. "1.9 MB".
    var fileSize: String { Int64(self).formatted(.byteCount(style: .file)) }
}

extension View {
    /// Swipe right from the left edge to go back, like a navigation stack.
    func swipeBack(_ action: @escaping () -> Void) -> some View {
        simultaneousGesture(
            DragGesture(minimumDistance: 24).onEnded { drag in
                if drag.startLocation.x < 36, drag.translation.width > 80, abs(drag.translation.height) < 80 { action() }
            })
    }
}
