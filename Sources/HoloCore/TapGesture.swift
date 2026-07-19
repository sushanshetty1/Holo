import Foundation

/// A single accepted tap, carried through gesture resolution.
public struct TapEvent: Equatable, Sendable {
    public let zone: DeskZone
    public let time: TimeInterval
    public let confidence: Double

    public init(zone: DeskZone, time: TimeInterval, confidence: Double) {
        self.zone = zone
        self.time = time
        self.confidence = confidence
    }
}

/// The gesture a short sequence of taps resolves to.
public enum TapGesture: Equatable, Sendable {
    case single(TapEvent)
    case double(first: TapEvent, second: TapEvent)

    public var zone: DeskZone {
        switch self {
        case .single(let event): return event.zone
        case .double(_, let second): return second.zone
        }
    }

    public var isDouble: Bool {
        if case .double = self { return true }
        return false
    }

    /// Confidence to gate the dispatched action on. For a double-tap we take the
    /// weaker of the two taps, so both must be clear.
    public var confidence: Double {
        switch self {
        case .single(let event): return event.confidence
        case .double(let first, let second): return min(first.confidence, second.confidence)
        }
    }
}

/// Resolves a stream of accepted taps into single/double-tap gestures.
///
/// A zone that has a double-tap action buffers its first tap for `window`
/// seconds to see whether a second same-zone tap follows. A zone with no
/// double-tap action fires immediately, keeping the pipeline's normal
/// responsiveness where the extra vocabulary isn't used.
public struct TapGestureResolver {
    public var window: TimeInterval
    private var pending: TapEvent?

    public init(window: TimeInterval = 0.4) {
        self.window = window
    }

    /// The buffered tap awaiting a possible second, if any. When non-nil, the
    /// caller should schedule a `flush` `window` seconds later.
    public var pendingEvent: TapEvent? { pending }

    /// Feed an accepted tap. Returns the gestures that resolved as a result —
    /// 0, 1, or 2 (a buffered single can resolve at the same moment a new,
    /// unrelated tap starts a fresh sequence).
    public mutating func register(_ event: TapEvent, supportsDouble: Bool) -> [TapGesture] {
        // A matching second tap within the window completes a double.
        if let first = pending, first.zone == event.zone, event.time - first.time <= window {
            pending = nil
            return [.double(first: first, second: event)]
        }

        var resolved: [TapGesture] = []
        // Any other buffered tap can no longer become a double; resolve it now.
        if let first = pending {
            pending = nil
            resolved.append(.single(first))
        }

        if supportsDouble {
            pending = event // wait for a possible second tap
        } else {
            resolved.append(.single(event))
        }
        return resolved
    }

    /// Resolve a buffered single once its window has elapsed. Call on a timer
    /// scheduled `window` seconds after a pending tap appears.
    public mutating func flush(at time: TimeInterval) -> [TapGesture] {
        guard let first = pending, time - first.time > window else { return [] }
        pending = nil
        return [.single(first)]
    }
}
