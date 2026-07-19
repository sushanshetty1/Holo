import AppKit
import SwiftUI

final class HoloAppDelegate: NSObject, NSApplicationDelegate {
    // Keep Holo running in the menu bar after the window is closed, so listening
    // continues and the status item stays available. Quit is explicit (menu
    // item or ⌘Q).
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

/// Observes the model so the menu bar glyph reflects listening vs. paused state,
/// and briefly pulses when a tap is accepted — live feedback even when the main
/// window is closed.
private struct MenuBarLabel: View {
    @ObservedObject var model: AppModel
    @State private var flashing = false

    var body: some View {
        Image(nsImage: HoloLogo.menuBarImage(listening: model.audio.isListening, emphasized: flashing))
            .onChange(of: model.lastDecision) { _, decision in
                guard decision?.wasAccepted == true else { return }
                flashing = true
                Task {
                    try? await Task.sleep(for: .milliseconds(260))
                    flashing = false
                }
            }
    }
}

@main
struct HoloApp: App {
    @NSApplicationDelegateAdaptor(HoloAppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("Holo", id: "main") {
            RootView(model: model)
                .frame(minWidth: 1_020, minHeight: 680)
                .task { await model.activateOnLaunch() }
        }
        .defaultSize(width: 1_180, height: 760)
        .commands {
            CommandMenu("Holo") {
                if model.selectedProfile == nil && model.guidedSection == nil {
                    Button("Set Up Desk") {
                        model.openSetup()
                    }
                } else {
                    Button(model.audio.isListening ? "Pause Listening" : "Resume Listening") {
                        model.togglePause()
                    }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                }

                Button("Recalibrate") {
                    model.prepareRecalibration()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(model.selectedProfile == nil || model.guidedSection != nil)
            }
        }

        MenuBarExtra {
            MenuBarPanel(model: model)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}
