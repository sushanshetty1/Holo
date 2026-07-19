import Foundation

/// Display-ready state for the menu bar status panel.
///
/// A pure mapping from the app's runtime state to the text, activity level, and
/// enabled flags the panel renders. It has no SwiftUI or AppKit dependency, so
/// the mapping can be unit-tested directly while the view layer stays thin.
public struct MenuBarStatus: Equatable, Sendable {
    /// Coarse sensing state, used to pick the status indicator color.
    public enum Activity: Equatable, Sendable {
        case listening
        case paused
        case setupNeeded
    }

    public let activity: Activity
    public let statusText: String
    public let lastTapText: String
    public let pauseTitle: String
    public let canRecalibrate: Bool

    public init(
        isListening: Bool,
        hasProfile: Bool,
        isGuidedSessionActive: Bool,
        lastZone: DeskZone?,
        statusMessage: String
    ) {
        if isListening {
            activity = .listening
        } else if hasProfile {
            activity = .paused
        } else {
            activity = .setupNeeded
        }

        statusText = statusMessage

        if let lastZone {
            lastTapText = "Last tap: \(lastZone.displayName)"
        } else {
            lastTapText = "No taps yet"
        }

        // Mirrors `AppModel.togglePause`: pause while listening, resume when a
        // profile exists, otherwise the tap starts desk setup.
        if isListening {
            pauseTitle = "Pause Listening"
        } else if hasProfile {
            pauseTitle = "Resume Listening"
        } else {
            pauseTitle = "Set Up Desk"
        }

        // Mirrors the Recalibrate command: unavailable with no profile or while
        // a guided calibration/evaluation session is in progress.
        canRecalibrate = hasProfile && !isGuidedSessionActive
    }
}
