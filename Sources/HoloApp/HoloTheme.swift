import AppKit
import SwiftUI

/// Holo's shared visual language: adaptive surfaces, spacing, and a small set of
/// reusable building blocks (screen scaffold, grouped cards, info rows) so every
/// screen reads as one calm, native instrument in both light and dark.
enum HoloTheme {
    static let background = Color.holoScreenBackground

    enum Space {
        static let screenPadding: CGFloat = 28
        static let contentWidth: CGFloat = 820
        static let sectionGap: CGFloat = 26
        static let cardRadius: CGFloat = 10
        static let rowHeight: CGFloat = 40
    }
}

// MARK: - Adaptive colors

private func adaptive(light: NSColor, dark: NSColor) -> NSColor {
    NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
    }
}

extension Color {
    /// The content (detail) background. Slightly lighter than the sidebar so the
    /// working area reads as the focus.
    static let holoScreenBackground = Color(nsColor: adaptive(
        light: NSColor(white: 0.965, alpha: 1), dark: NSColor(white: 0.11, alpha: 1)))
    /// A grouped card that sits above the screen background (elevated in dark).
    static let holoCard = Color(nsColor: adaptive(
        light: .white, dark: NSColor(white: 0.16, alpha: 1)))
    /// Hairline separators and card borders.
    static let holoSeparator = Color(nsColor: adaptive(
        light: NSColor.black.withAlphaComponent(0.07), dark: NSColor.white.withAlphaComponent(0.08)))
    /// The pinned sidebar status card.
    static let holoFooter = Color(nsColor: adaptive(
        light: NSColor(white: 0.90, alpha: 1), dark: NSColor(white: 0.125, alpha: 1)))
}

// MARK: - Screen scaffold

/// A standard screen: a large title, an optional one-line subtitle, then the
/// screen's content in a comfortably-wide, scrollable column over the shared
/// background. Every primary screen uses this so titles, width, and spacing match.
struct HoloScreen<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HoloTheme.Space.sectionGap) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 26, weight: .bold))
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                content()
            }
            .frame(maxWidth: HoloTheme.Space.contentWidth, alignment: .leading)
            .padding(HoloTheme.Space.screenPadding)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HoloTheme.background)
    }
}

// MARK: - Grouped section (header + content)

/// A titled section: a semibold header, then any content (usually a card).
struct HoloGroup<Content: View>: View {
    let title: String?
    var footnote: String? = nil
    @ViewBuilder var content: () -> Content

    init(_ title: String? = nil, footnote: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.footnote = footnote
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            content()
            if let footnote {
                Label {
                    Text(footnote)
                } icon: {
                    Image(systemName: "info.circle")
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.top, 1)
            }
        }
    }
}

// MARK: - Card surface

/// Wraps content in Holo's grouped-card surface (fill + hairline border).
struct HoloCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: HoloTheme.Space.cardRadius, style: .continuous).fill(Color.holoCard))
            .overlay(RoundedRectangle(cornerRadius: HoloTheme.Space.cardRadius, style: .continuous).strokeBorder(Color.holoSeparator, lineWidth: 1))
    }
}

extension View {
    /// Applies Holo's grouped-card surface (fill + hairline border).
    func holoCard() -> some View { modifier(HoloCardStyle()) }
}

// MARK: - Info rows

/// One label→value line for a display card. `mono` renders the value with a
/// monospaced digit face for numbers that should stay aligned.
struct HoloInfoRow: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    var mono = false
    var valueColor: Color = .secondary
}

/// A card of read-only label→value rows with hairline separators between them —
/// the calm replacement for a boxed `Form` section.
struct HoloInfoCard: View {
    let rows: [HoloInfoRow]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                HStack {
                    Text(row.label)
                        .font(.system(size: 13))
                    Spacer(minLength: 16)
                    Text(row.value)
                        .font(.system(size: 13, design: row.mono ? .monospaced : .default))
                        .foregroundStyle(row.valueColor)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: HoloTheme.Space.rowHeight)
                if index < rows.count - 1 {
                    Rectangle().fill(Color.holoSeparator).frame(height: 1).padding(.leading, 14)
                }
            }
        }
        .holoCard()
    }
}

// MARK: - Buttons

extension View {
    @ViewBuilder
    func holoPrimaryButton() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    func holoSecondaryButton() -> some View {
        self.buttonStyle(.bordered)
    }
}
