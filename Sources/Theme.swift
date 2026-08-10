import SwiftUI

// Brand palette mirroring the web app's CSS variables.
enum Palette {
    static let accent = Color(hex: 0x8B5CF6)   // violet
    static let accent2 = Color(hex: 0x22D3EE)  // cyan

    // ShapeStyle gradient for text/fills.
    static let brand = LinearGradient(colors: [accent, accent2],
                                      startPoint: .leading, endPoint: .trailing)

    static func bg(_ light: Bool) -> Color { light ? Color(hex: 0xF6F7FB) : Color(hex: 0x0B0B12) }
    static func card(_ light: Bool) -> Color { light ? .white : Color(hex: 0x15151F) }
    static func text(_ light: Bool) -> Color { light ? Color(hex: 0x14141B) : Color(hex: 0xF3F3F7) }
    static func muted(_ light: Bool) -> Color { light ? Color(hex: 0x5A5A6E) : Color(hex: 0x9A9AAd) }
    static func line(_ light: Bool) -> Color { light ? Color(hex: 0xE3E4EC) : Color(hex: 0x26263a) }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

struct BrandGradient: View {
    var body: some View {
        LinearGradient(colors: [Palette.accent, Palette.accent2],
                       startPoint: .leading, endPoint: .trailing)
    }
}

// A themed card container.
struct Card<Content: View>: View {
    @EnvironmentObject var store: Store
    let content: Content
    init(@ViewBuilder _ content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.card(store.lightMode))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.line(store.lightMode), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct Pill: View {
    @EnvironmentObject var store: Store
    let text: String
    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Palette.accent.opacity(0.15))
            .foregroundColor(Palette.accent)
            .clipShape(Capsule())
    }
}

struct KPI: View {
    @EnvironmentObject var store: Store
    let value: String
    let label: String
    var sub: String? = nil
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 4) {
                Text(value).font(.title2.bold()).foregroundStyle(Palette.brand)
                Text(label).font(.caption).foregroundColor(Palette.muted(store.lightMode))
                if let sub { Text(sub).font(.caption2).foregroundColor(Palette.muted(store.lightMode)) }
            }
        }
    }
}

// Section header.
struct SectionTitle: View {
    @EnvironmentObject var store: Store
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.title3.bold()).foregroundColor(Palette.text(store.lightMode))
            if let subtitle { Text(subtitle).font(.subheadline).foregroundColor(Palette.muted(store.lightMode)) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Stars: View {
    let value: Double
    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<5) { i in
                Image(systemName: Double(i) + 1 <= value.rounded() ? "star.fill" : "star")
                    .font(.caption2)
                    .foregroundColor(.yellow)
            }
        }
    }
}

// Circular avatar with initials on the brand gradient.
struct Avatar: View {
    let name: String
    var size: CGFloat = 56
    private var initials: String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }
    var body: some View {
        Circle()
            .fill(Palette.brand)
            .frame(width: size, height: size)
            .overlay(Text(initials).font(.system(size: size * 0.38, weight: .bold)).foregroundColor(.white))
    }
}

// Achievement chip — glows when unlocked, dimmed when locked.
struct AchievementChip: View {
    @EnvironmentObject var store: Store
    let icon: String
    let label: String
    let unlocked: Bool
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(unlocked ? AnyShapeStyle(Palette.brand) : AnyShapeStyle(Palette.muted(store.lightMode)))
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundColor(unlocked ? Palette.text(store.lightMode) : Palette.muted(store.lightMode))
        }
        .frame(maxWidth: .infinity, minHeight: 74)
        .padding(8)
        .background(unlocked ? Palette.accent.opacity(0.12) : Palette.card(store.lightMode))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(unlocked ? Palette.accent.opacity(0.5) : Palette.line(store.lightMode), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .opacity(unlocked ? 1 : 0.55)
    }
}

struct AchievementGrid: View {
    let items: [Store.Achievement]
    private let cols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    var body: some View {
        LazyVGrid(columns: cols, spacing: 10) {
            ForEach(items) { a in AchievementChip(icon: a.icon, label: a.label, unlocked: a.unlocked) }
        }
    }
}

// Level / XP progress bar for instructor gamification.
struct LevelBar: View {
    @EnvironmentObject var store: Store
    let instructor: Instructor
    var body: some View {
        let lvl = store.instructorLevel(instructor)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Lvl \(lvl) · \(store.levelTitle(instructor))")
                    .font(.subheadline.bold()).foregroundStyle(Palette.brand)
                Spacer()
                if let xp = store.xpToNext(instructor) {
                    Text("\(xp) XP to next").font(.caption2).foregroundColor(Palette.muted(store.lightMode))
                } else {
                    Text("MAX").font(.caption2.bold()).foregroundColor(Palette.accent2)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.line(store.lightMode)).frame(height: 8)
                    Capsule().fill(Palette.brand)
                        .frame(width: max(8, geo.size.width * store.levelProgress(instructor)), height: 8)
                }
            }.frame(height: 8)
            Text("\(store.instructorXP(instructor)) XP total").font(.caption2).foregroundColor(Palette.muted(store.lightMode))
        }
    }
}

// Heart toggle for favoriting / following.
struct HeartButton: View {
    let isOn: Bool
    var count: Int? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: isOn ? "heart.fill" : "heart")
                    .foregroundStyle(isOn ? AnyShapeStyle(Palette.brand) : AnyShapeStyle(Color.secondary))
                if let count { Text("\(count)").font(.caption2.bold()).foregroundColor(.secondary) }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Capsule().stroke(Color.secondary.opacity(0.3), lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// Compact circular XP ring showing progress toward the next level.
struct CircularXPRing: View {
    @EnvironmentObject var store: Store
    let instructor: Instructor
    var size: CGFloat = 58
    var body: some View {
        let lvl = store.instructorLevel(instructor)
        let progress = store.levelProgress(instructor)
        ZStack {
            Circle().stroke(Palette.line(store.lightMode), lineWidth: 6)
            Circle()
                .trim(from: 0, to: max(0.02, progress))
                .stroke(Palette.brand, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("LVL").font(.system(size: 8, weight: .bold)).foregroundColor(Palette.muted(store.lightMode))
                Text("\(lvl)").font(.system(size: size * 0.34, weight: .heavy)).foregroundColor(Palette.text(store.lightMode))
            }
        }
        .frame(width: size, height: size)
    }
}
