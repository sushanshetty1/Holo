import AppKit
import HoloCore
import SwiftUI

/// The window-style panel shown when the menu bar logo is clicked: a live status
/// glance plus quick controls. All display text and enabled flags come from the
/// pure `MenuBarStatus`; this view only lays them out and forwards taps.
struct MenuBarPanel: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @State private var rippleTrigger = 0

    private var status: MenuBarStatus {
        MenuBarStatus(
            isListening: model.audio.isListening,
            hasProfile: model.selectedProfile != nil,
            isGuidedSessionActive: model.guidedSection != nil,
            lastZone: model.lastDecision?.zone,
            statusMessage: model.statusMessage
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            statusBlock
            Divider().padding(.vertical, 8)
            actions
        }
        .padding(12)
        .frame(width: 264)
        .onChange(of: model.lastDecision) { _, decision in
            if decision?.wasAccepted == true { rippleTrigger += 1 }
        }
    }

    private var header: some View {
        HStack(spacing: 9) {
            HoloLogoView(
                tint: .accentColor,
                listening: status.activity == .listening,
                rippleTrigger: rippleTrigger
            )
            .frame(width: 22, height: 22)

            Text("Holo")
                .font(.system(size: 15, weight: .semibold))
            Spacer(minLength: 0)
        }
        .padding(.bottom, 10)
    }

    private var statusBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Circle()
                    .fill(activityColor)
                    .frame(width: 8, height: 8)
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                Text(status.statusText)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(status.lastTapText)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.leading, 15)
        }
    }

    private var actions: some View {
        VStack(spacing: 1) {
            MenuActionRow(
                symbol: status.activity == .listening ? "pause.fill" : "play.fill",
                title: status.pauseTitle
            ) {
                model.togglePause()
            }

            MenuActionRow(symbol: "scope", title: "Recalibrate", enabled: status.canRecalibrate) {
                model.prepareRecalibration()
                showWindow()
            }

            MenuActionRow(symbol: "macwindow", title: "Open Holo Window") {
                showWindow()
            }

            Divider().padding(.vertical, 5)

            MenuActionRow(symbol: "power", title: "Quit Holo") {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private var activityColor: Color {
        switch status.activity {
        case .listening: return .green
        case .paused: return .secondary
        case .setupNeeded: return .orange
        }
    }

    private func showWindow() {
        openWindow(id: "main")
        NSApplication.shared.activate()
    }
}

/// A full-width, hover-highlighting menu row. Keeps the panel controls reading
/// like a native menu inside the window-style `MenuBarExtra`.
private struct MenuActionRow: View {
    let symbol: String
    let title: String
    var enabled: Bool = true
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .frame(width: 16)
                Text(title)
                Spacer(minLength: 0)
            }
            .font(.system(size: 13))
            .foregroundStyle(enabled ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(hovering && enabled ? Color.primary.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .onHover { hovering = $0 }
    }
}
