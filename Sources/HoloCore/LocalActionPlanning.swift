import Foundation

public enum LocalActionCommand: Equatable, Sendable {
    case playSound(name: String)
    case copyText(String)
    case speakText(String)
    case openURL(URL)
    case runShortcut(URL)
    case openApplication(bookmarkData: Data)
    case openItem(bookmarkData: Data)
    case runShellCommand(String)
    case takeScreenshot(interactive: Bool)
}

public enum LocalActionPlanner {
    /// Converts a saved zone action into a validated side-effect command. `nil`
    /// means visual feedback only or an action that is not fully configured.
    public static func command(for action: ZoneActionConfiguration) -> LocalActionCommand? {
        switch action.kind {
        case .none:
            return nil

        case .sound:
            let name = action.soundName.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : .playSound(name: name)

        case .copyText:
            return hasContent(action.text) ? .copyText(action.text) : nil

        case .speakText:
            return hasContent(action.text) ? .speakText(action.text) : nil

        case .openURL:
            var candidate = action.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !candidate.isEmpty else { return nil }
            if !candidate.contains("://") { candidate = "https://" + candidate }
            guard let url = URL(string: candidate),
                  ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
                  url.host?.isEmpty == false else { return nil }
            return .openURL(url)

        case .runShortcut:
            let name = action.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            var components = URLComponents()
            components.scheme = "shortcuts"
            components.host = "run-shortcut"
            components.queryItems = [URLQueryItem(name: "name", value: name)]
            return components.url.map(LocalActionCommand.runShortcut)

        case .openApplication:
            guard let bookmarkData = action.bookmarkData, !bookmarkData.isEmpty else { return nil }
            return .openApplication(bookmarkData: bookmarkData)

        case .openItem:
            guard let bookmarkData = action.bookmarkData, !bookmarkData.isEmpty else { return nil }
            return .openItem(bookmarkData: bookmarkData)

        case .runShellCommand:
            let command = action.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !command.isEmpty, !command.contains("\0") else { return nil }
            return .runShellCommand(command)

        case .screenshotClipboard:
            return .takeScreenshot(interactive: false)

        case .screenshotSelection:
            return .takeScreenshot(interactive: true)
        }
    }

    private static func hasContent(_ text: String) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

public extension ZoneActionKind {
    /// The minimum classifier confidence required to *automatically* run this
    /// action. An accepted tap always identifies its zone, but consequential
    /// actions demand a clearer decision than the base accept, so a borderline
    /// tap cannot fire something with real side effects.
    var minimumAutomaticConfidence: Double {
        switch self {
        case .none, .sound, .copyText, .speakText:
            // Benign: reversible or purely local. The base accept is enough.
            return ClassifierDefaults.minimumConfidence
        case .openURL, .runShortcut, .openApplication, .openItem,
             .screenshotClipboard, .screenshotSelection:
            // Consequential: launches something or captures the screen.
            return 0.50
        case .runShellCommand:
            // Highest impact: runs arbitrary code. Require the strongest signal.
            return 0.62
        }
    }
}

public enum LocalActionDispatchPolicy {
    /// Automatic side effects are confined to the live Desk surface. Guided
    /// capture and configuration screens can still classify for feedback, but
    /// only an accepted Desk decision may run an assigned action.
    public static func allowsAutomaticDispatch(
        for decision: ClassificationDecision,
        isDeskActive: Bool
    ) -> Bool {
        isDeskActive && decision.wasAccepted
    }

    /// As above, but also requires the decision's confidence to clear the
    /// action's automatic bar. The zone is still identified for visual feedback
    /// when this returns `false`; only the side effect is withheld.
    public static func allowsAutomaticDispatch(
        for decision: ClassificationDecision,
        action: ZoneActionKind,
        isDeskActive: Bool
    ) -> Bool {
        allowsAutomaticDispatch(for: decision, isDeskActive: isDeskActive)
            && decision.confidence >= action.minimumAutomaticConfidence
    }
}
