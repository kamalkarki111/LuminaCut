import SwiftUI

/// CapCut × CRED inspired dark premium theme
enum CutTheme {
    // Deep blacks (CapCut canvas + CRED card stack)
    static let bg = Color(hex: "050506")
    static let surface = Color(hex: "0C0C0E")
    static let surfaceElevated = Color(hex: "141417")
    static let surfaceHover = Color(hex: "1C1C21")
    static let surfaceCard = Color(hex: "121216")

    static let border = Color.white.opacity(0.06)
    static let borderStrong = Color.white.opacity(0.12)
    static let borderGlow = Color(hex: "FE2C55").opacity(0.35)

    static let textPrimary = Color.white.opacity(0.96)
    static let textSecondary = Color.white.opacity(0.58)
    static let textTertiary = Color.white.opacity(0.34)

    // CapCut signature pink-red + CRED violet accents
    static let accent = Color(hex: "FE2C55")
    static let accentPink = Color(hex: "FF4D6D")
    static let accentPurple = Color(hex: "8B5CF6")
    static let accentViolet = Color(hex: "A78BFA")
    static let accentCyan = Color(hex: "22D3EE")
    static let accentGreen = Color(hex: "34D399")
    static let accentOrange = Color(hex: "FB923C")
    static let accentBlue = Color(hex: "5B8CFF")
    static let danger = Color(hex: "FF5A5A")
    static let playhead = Color(hex: "FE2C55")
    static let timelineBg = Color(hex: "08080A")

    static let accentGradient = LinearGradient(
        colors: [Color(hex: "FE2C55"), Color(hex: "FF6B8A"), Color(hex: "A78BFA")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let credGlow = LinearGradient(
        colors: [Color(hex: "FE2C55").opacity(0.5), Color(hex: "8B5CF6").opacity(0.35), Color.clear],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let sidebarWidth: CGFloat = 248
    static let inspectorWidth: CGFloat = 292
    static let chatWidth: CGFloat = 308
    static let topBarHeight: CGFloat = 52
    static let toolRailWidth: CGFloat = 68
    static let pixelsPerSecond: CGFloat = 84

    static let radiusSm: CGFloat = 8
    static let radiusMd: CGFloat = 12
    static let radiusLg: CGFloat = 16
    static let radiusXl: CGFloat = 22
}

// MARK: - Shared chrome

struct CutCardBackground: View {
    var elevated: Bool = false
    var body: some View {
        RoundedRectangle(cornerRadius: CutTheme.radiusMd, style: .continuous)
            .fill(elevated ? CutTheme.surfaceElevated : CutTheme.surfaceCard)
            .overlay(
                RoundedRectangle(cornerRadius: CutTheme.radiusMd, style: .continuous)
                    .stroke(CutTheme.border, lineWidth: 1)
            )
    }
}

struct CutSectionHeader: View {
    let title: String
    var trailing: String? = nil
    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(CutTheme.textTertiary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(CutTheme.textTertiary)
            }
        }
    }
}

struct CutPillButton: View {
    let title: String
    var icon: String? = nil
    var selected: Bool = false
    var compact: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: compact ? 10 : 11, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: compact ? 10 : 11, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(selected ? .white : CutTheme.textSecondary)
            .padding(.horizontal, compact ? 10 : 12)
            .padding(.vertical, compact ? 6 : 8)
            .background(
                Capsule(style: .continuous)
                    .fill(selected ? AnyShapeStyle(CutTheme.accentGradient) : AnyShapeStyle(CutTheme.surfaceHover))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(selected ? CutTheme.accent.opacity(0.5) : CutTheme.border, lineWidth: 1)
                    )
            )
            .shadow(color: selected ? CutTheme.accent.opacity(0.35) : .clear, radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct CutIconButton: View {
    let icon: String
    var selected: Bool = false
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(disabled ? CutTheme.textTertiary : (selected ? .white : CutTheme.textSecondary))
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: CutTheme.radiusSm, style: .continuous)
                        .fill(selected ? CutTheme.accent.opacity(0.9) : CutTheme.surfaceHover)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CutTheme.radiusSm, style: .continuous)
                        .stroke(selected ? CutTheme.accentPink.opacity(0.6) : CutTheme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    var range: ClosedRange<Double> = -1...1
    var defaultValue: Double = 0
    var displayMultiplier: Double = 100
    var onEdit: ((Bool) -> Void)? = nil
    var icon: String? = nil

    @State private var dragging = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(CutTheme.textTertiary)
                        .frame(width: 14)
                }
                Text(title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(CutTheme.textSecondary)
                Spacer()
                Text(String(format: "%.0f", value * displayMultiplier))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(dragging ? CutTheme.accent : CutTheme.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(CutTheme.surfaceHover))
            }

            GeometryReader { geo in
                let w = geo.size.width
                let p = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
                let zero = (0 - range.lowerBound) / (range.upperBound - range.lowerBound)

                ZStack(alignment: .leading) {
                    Capsule().fill(CutTheme.surfaceHover).frame(height: 5)
                    if range.lowerBound < 0 {
                        let left = min(zero, p) * w
                        let width = abs(p - zero) * w
                        Capsule().fill(CutTheme.accentGradient).frame(width: max(0, width), height: 5).offset(x: left)
                    } else {
                        Capsule().fill(CutTheme.accentGradient).frame(width: max(0, p * w), height: 5)
                    }
                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                        .shadow(color: CutTheme.accent.opacity(0.45), radius: 4, y: 1)
                        .overlay(Circle().stroke(CutTheme.accent.opacity(0.3), lineWidth: 1))
                        .offset(x: p * w - 7)
                }
                .frame(height: 18)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            if !dragging { dragging = true; onEdit?(true) }
                            let np = min(1, max(0, g.location.x / w))
                            value = range.lowerBound + np * (range.upperBound - range.lowerBound)
                        }
                        .onEnded { _ in
                            dragging = false
                            onEdit?(false)
                        }
                )
                .onTapGesture(count: 2) { value = defaultValue }
            }
            .frame(height: 18)
        }
    }
}
