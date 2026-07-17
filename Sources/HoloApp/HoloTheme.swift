import AppKit
import SwiftUI

enum HoloTheme {
    static let background = Color(nsColor: .windowBackgroundColor)
}

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
