import AppKit
import SwiftUI

/// Holo's mark: a top-down acoustic ripple — a solid impact point with two
/// concentric rings whose weight and opacity decay outward. Rendered two ways:
/// a monochrome template image for the macOS menu bar, and a tinted SwiftUI
/// view (with a one-shot tap ripple) for the status panel header.
enum HoloLogo {
    /// Fractions of the drawing's shorter side. Shared by both render paths so
    /// the menu bar glyph and the panel logo stay identical in proportion.
    fileprivate enum Metric {
        static let outerRadius: CGFloat = 0.44
        static let innerRadius: CGFloat = 0.28
        static let dotRadius: CGFloat = 0.072
        static let outerLineWidth: CGFloat = 0.028
        static let innerLineWidth: CGFloat = 0.044
        static let hollowLineWidth: CGFloat = 0.040

        // Opacity decays outward so the mark reads as an expanding ripple.
        static func innerAlpha(listening: Bool) -> CGFloat { listening ? 0.90 : 0.45 }
        static func outerAlpha(listening: Bool) -> CGFloat { listening ? 0.36 : 0.20 }
    }

    /// A template (auto-tinting) menu bar image. The listening variant fills the
    /// center; the paused variant hollows it and fades the rings so the glyph
    /// reads as inactive at a glance.
    static func menuBarImage(listening: Bool) -> NSImage {
        listening ? listeningImage : pausedImage
    }

    private static let listeningImage = makeMenuBarImage(listening: true)
    private static let pausedImage = makeMenuBarImage(listening: false)

    private static func makeMenuBarImage(listening: Bool) -> NSImage {
        let side: CGFloat = 18
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let s = min(rect.width, rect.height)

            func ring(radius: CGFloat, lineWidth: CGFloat, alpha: CGFloat) {
                let r = s * radius
                let path = NSBezierPath(ovalIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
                path.lineWidth = s * lineWidth
                NSColor.black.withAlphaComponent(alpha).setStroke()
                path.stroke()
            }

            ring(radius: Metric.outerRadius, lineWidth: Metric.outerLineWidth, alpha: Metric.outerAlpha(listening: listening))
            ring(radius: Metric.innerRadius, lineWidth: Metric.innerLineWidth, alpha: Metric.innerAlpha(listening: listening))

            let dotR = s * Metric.dotRadius
            let dot = NSBezierPath(ovalIn: CGRect(x: center.x - dotR, y: center.y - dotR, width: dotR * 2, height: dotR * 2))
            if listening {
                NSColor.black.setFill()
                dot.fill()
            } else {
                dot.lineWidth = s * Metric.hollowLineWidth
                NSColor.black.withAlphaComponent(0.6).setStroke()
                dot.stroke()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}

/// The tinted, resolution-independent ripple used in the status panel header.
struct HoloLogoView: View {
    var tint: Color = .accentColor
    var listening: Bool = true
    /// Increment to fire a single expanding-ring animation on a real tap.
    var rippleTrigger: Int = 0

    @State private var rippleScale: CGFloat = 0.5
    @State private var rippleOpacity: Double = 0

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let s = min(size.width, size.height)

            func ringPath(_ radius: CGFloat) -> Path {
                let r = s * radius
                return Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
            }

            context.stroke(
                ringPath(HoloLogo.Metric.outerRadius),
                with: .color(tint.opacity(HoloLogo.Metric.outerAlpha(listening: listening))),
                lineWidth: s * HoloLogo.Metric.outerLineWidth
            )
            context.stroke(
                ringPath(HoloLogo.Metric.innerRadius),
                with: .color(tint.opacity(HoloLogo.Metric.innerAlpha(listening: listening))),
                lineWidth: s * HoloLogo.Metric.innerLineWidth
            )

            let dotR = s * HoloLogo.Metric.dotRadius
            let dot = Path(ellipseIn: CGRect(x: center.x - dotR, y: center.y - dotR, width: dotR * 2, height: dotR * 2))
            if listening {
                context.fill(dot, with: .color(tint))
            } else {
                context.stroke(dot, with: .color(tint.opacity(0.6)), lineWidth: s * HoloLogo.Metric.hollowLineWidth)
            }
        }
        .overlay(
            Circle()
                .stroke(tint, lineWidth: 1.5)
                .scaleEffect(rippleScale)
                .opacity(rippleOpacity)
        )
        .onChange(of: rippleTrigger) { _, _ in
            rippleScale = 0.5
            rippleOpacity = 0.55
            withAnimation(.easeOut(duration: 0.6)) {
                rippleScale = 1.05
                rippleOpacity = 0
            }
        }
    }
}
