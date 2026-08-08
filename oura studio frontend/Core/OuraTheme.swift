import SwiftUI

enum OuraTheme {
    enum Colors {
        // Backgrounds
        static let background    = Color(red: 0.9298, green: 0.9036, blue: 0.8836)
        static let surfaceCard   = Color(red: 0.9942, green: 0.9855, blue: 0.9760)
        static let surfaceSheet  = Color(red: 0.9687, green: 0.9513, blue: 0.9324)
        static let surfaceAlt    = Color(red: 0.9707, green: 0.9274, blue: 0.8802)

        // Borders
        static let border        = Color(red: 0.8780, green: 0.8521, blue: 0.8324)
        static let separator     = Color(red: 0.8268, green: 0.8012, blue: 0.7817)

        // Text
        static let textPrimary   = Color(red: 0.1539, green: 0.1121, blue: 0.0893)
        static let textSecondary = Color(red: 0.4508, green: 0.3994, blue: 0.3720)
        static let textTertiary  = Color(red: 0.6290, green: 0.5875, blue: 0.5655)
        static let textDisabled  = Color(red: 0.5211, green: 0.4976, blue: 0.4797)

        // Brand / Accent (terracotta)
        static let accent              = Color(red: 0.7461, green: 0.3384, blue: 0.2384)
        static let accentGradientStart = Color(red: 0.7893, green: 0.3478, blue: 0.2395)
        static let accentGradientEnd   = Color(red: 0.6795, green: 0.2995, blue: 0.2462)
        static let accentLight         = Color(red: 1.0000, green: 0.8923, blue: 0.8615)

        // Danger (red)
        static let dangerText = Color(red: 0.7719, green: 0.2111, blue: 0.2154)
        static let dangerBg   = Color(red: 1.0000, green: 0.8747, blue: 0.8567)

        // Warning (amber)
        static let warningText = Color(red: 0.7321, green: 0.4161, blue: 0.0000)
        static let warningBg   = Color(red: 1.0000, green: 0.9238, blue: 0.7900)

        // Blue (teal)
        static let blueAccent = Color(red: 0.0000, green: 0.4476, blue: 0.4682)
        static let blueBg     = Color(red: 0.8227, green: 0.9349, blue: 0.9400)

        // Green
        static let greenAccent = Color(red: 0.2804, green: 0.5805, blue: 0.2998)
        static let greenBg     = Color(red: 0.8603, green: 0.9522, blue: 0.8594)

        // Purple
        static let purple   = Color(red: 0.6583, green: 0.5651, blue: 0.8299)
        static let purpleBg = Color(red: 0.9400, green: 0.9200, blue: 0.9800)

        // Gradients
        static let accentGradient = LinearGradient(
            colors: [accentGradientStart, accentGradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    enum Radius {
        static let small: CGFloat    = 8
        static let medium: CGFloat   = 12
        static let standard: CGFloat = 16
        static let card: CGFloat     = 18
        static let large: CGFloat    = 22
        static let sheet: CGFloat    = 24
    }

    enum Spacing {
        static let horizontal: CGFloat    = 20
        static let sectionGap: CGFloat    = 24
        static let cardPad: CGFloat       = 16
        static let listItemV: CGFloat     = 13
        static let listItemH: CGFloat     = 16
    }
}

// MARK: - View modifiers

extension View {
    func ouraCard(_ radius: CGFloat = OuraTheme.Radius.card) -> some View {
        self
            .background(OuraTheme.Colors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(OuraTheme.Colors.border, lineWidth: 0.75)
            )
    }

    func ouraListRow() -> some View {
        self
            .listRowBackground(OuraTheme.Colors.surfaceCard)
            .listRowInsets(EdgeInsets(
                top: OuraTheme.Spacing.listItemV,
                leading: OuraTheme.Spacing.listItemH,
                bottom: OuraTheme.Spacing.listItemV,
                trailing: OuraTheme.Spacing.listItemH
            ))
            .listRowSeparatorTint(OuraTheme.Colors.separator)
    }
}

// MARK: - OuraTag (badge/chip)

struct OuraTag: View {
    let text: String
    var color: Color = OuraTheme.Colors.accent
    var bg: Color = OuraTheme.Colors.accentLight

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(bg)
            .clipShape(Capsule())
    }
}

// MARK: - OuraSectionHeader

struct OuraSectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(OuraTheme.Colors.textTertiary)
            .kerning(0.5)
    }
}

// MARK: - OuraFAB (floating action button)

struct OuraFAB: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(OuraTheme.Colors.accentGradient)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: OuraTheme.Colors.accent.opacity(0.35), radius: 8, x: 0, y: 4)
        }
    }
}

// MARK: - OuraPrimaryButton

struct OuraPrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .foregroundStyle(.white)
            .background(OuraTheme.Colors.accentGradient)
            .clipShape(RoundedRectangle(cornerRadius: OuraTheme.Radius.medium))
        }
        .disabled(isLoading)
    }
}

// MARK: - Formatting helpers

extension Double {
    var rupiahFormatted: String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.groupingSeparator = "."
        fmt.maximumFractionDigits = 0
        return "Rp\(fmt.string(from: NSNumber(value: self)) ?? "0")"
    }
}

extension Int {
    var rupiahFormatted: String { Double(self).rupiahFormatted }
}
