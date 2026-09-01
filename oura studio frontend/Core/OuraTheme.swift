import SwiftUI

enum OuraTheme {
    enum Colors {
        // Adaptive helper
        private static func c(
            l: (CGFloat, CGFloat, CGFloat),
            d: (CGFloat, CGFloat, CGFloat)
        ) -> Color {
            Color(UIColor { t in
                t.userInterfaceStyle == .dark
                    ? UIColor(red: d.0, green: d.1, blue: d.2, alpha: 1)
                    : UIColor(red: l.0, green: l.1, blue: l.2, alpha: 1)
            })
        }

        // Backgrounds
        static let background   = c(l: (0.930, 0.904, 0.884), d: (0.102, 0.090, 0.082))
        static let surfaceCard  = c(l: (0.994, 0.986, 0.976), d: (0.149, 0.133, 0.122))
        static let surfaceSheet = c(l: (0.969, 0.951, 0.932), d: (0.129, 0.114, 0.106))
        static let surfaceAlt   = c(l: (0.971, 0.927, 0.880), d: (0.137, 0.122, 0.102))

        // Borders
        static let border     = c(l: (0.878, 0.852, 0.832), d: (0.227, 0.208, 0.188))
        static let separator  = c(l: (0.827, 0.801, 0.782), d: (0.180, 0.165, 0.153))

        // Text
        static let textPrimary   = c(l: (0.154, 0.112, 0.089), d: (0.929, 0.906, 0.878))
        static let textSecondary = c(l: (0.451, 0.399, 0.372), d: (0.659, 0.596, 0.565))
        static let textTertiary  = c(l: (0.629, 0.588, 0.565), d: (0.420, 0.376, 0.349))
        static let textDisabled  = c(l: (0.521, 0.498, 0.480), d: (0.314, 0.286, 0.282))

        // Brand / Accent (terracotta — slightly brighter in dark)
        static let accent              = c(l: (0.746, 0.338, 0.238), d: (0.816, 0.416, 0.314))
        static let accentGradientStart = c(l: (0.789, 0.348, 0.239), d: (0.851, 0.435, 0.322))
        static let accentGradientEnd   = c(l: (0.679, 0.300, 0.246), d: (0.745, 0.365, 0.267))
        static let accentLight         = c(l: (1.000, 0.892, 0.862), d: (0.239, 0.102, 0.078))

        // Danger (red)
        static let dangerText = c(l: (0.772, 0.211, 0.215), d: (0.910, 0.376, 0.376))
        static let dangerBg   = c(l: (1.000, 0.875, 0.857), d: (0.239, 0.063, 0.063))

        // Warning (amber)
        static let warningText = c(l: (0.732, 0.416, 0.000), d: (0.980, 0.706, 0.251))
        static let warningBg   = c(l: (1.000, 0.924, 0.790), d: (0.239, 0.157, 0.000))

        // Blue (teal)
        static let blueAccent = c(l: (0.000, 0.448, 0.468), d: (0.200, 0.722, 0.753))
        static let blueBg     = c(l: (0.823, 0.935, 0.940), d: (0.047, 0.180, 0.196))

        // Green
        static let greenAccent = c(l: (0.280, 0.580, 0.300), d: (0.333, 0.710, 0.353))
        static let greenBg     = c(l: (0.860, 0.952, 0.859), d: (0.059, 0.165, 0.063))

        // Purple
        static let purple   = c(l: (0.658, 0.565, 0.830), d: (0.722, 0.627, 0.878))
        static let purpleBg = c(l: (0.940, 0.920, 0.980), d: (0.118, 0.098, 0.196))

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
    let id: String
    let action: () -> Void

    init(id: String = "fab-tambah", action: @escaping () -> Void) {
        self.id = id
        self.action = action
    }

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
        .accessibilityIdentifier(id)
    }
}

// MARK: - OuraPrimaryButton

struct OuraPrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    var testId: String? = nil
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
        .accessibilityIdentifier(testId ?? "btn-primary-\(title.replacingOccurrences(of: " ", with: "-").lowercased())")
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
