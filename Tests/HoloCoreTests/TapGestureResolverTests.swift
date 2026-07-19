import XCTest
@testable import HoloCore

final class TapGestureResolverTests: XCTestCase {
    private func event(_ zone: DeskZone, _ time: TimeInterval, confidence: Double = 0.8) -> TapEvent {
        TapEvent(zone: zone, time: time, confidence: confidence)
    }

    func testZoneWithoutDoubleFiresSingleImmediately() {
        var resolver = TapGestureResolver(window: 0.4)
        let gestures = resolver.register(event(.leftTop, 0), supportsDouble: false)
        XCTAssertEqual(gestures, [.single(event(.leftTop, 0))])
        XCTAssertNil(resolver.pendingEvent)
    }

    func testZoneWithDoubleBuffersThenFlushesAsSingle() {
        var resolver = TapGestureResolver(window: 0.4)
        let immediate = resolver.register(event(.leftTop, 0), supportsDouble: true)
        XCTAssertTrue(immediate.isEmpty)
        XCTAssertNotNil(resolver.pendingEvent)

        // Window not yet elapsed → nothing.
        XCTAssertTrue(resolver.flush(at: 0.3).isEmpty)
        // Window elapsed → single resolves.
        XCTAssertEqual(resolver.flush(at: 0.5), [.single(event(.leftTop, 0))])
        XCTAssertNil(resolver.pendingEvent)
    }

    func testTwoQuickSameZoneTapsResolveAsDouble() {
        var resolver = TapGestureResolver(window: 0.4)
        _ = resolver.register(event(.rightBottom, 0, confidence: 0.9), supportsDouble: true)
        let gestures = resolver.register(event(.rightBottom, 0.2, confidence: 0.6), supportsDouble: true)
        XCTAssertEqual(gestures, [.double(first: event(.rightBottom, 0, confidence: 0.9),
                                          second: event(.rightBottom, 0.2, confidence: 0.6))])
        XCTAssertNil(resolver.pendingEvent)
    }

    func testDoubleConfidenceIsWeakerOfTheTwo() {
        let gesture = TapGesture.double(first: event(.leftTop, 0, confidence: 0.9),
                                        second: event(.leftTop, 0.2, confidence: 0.55))
        XCTAssertEqual(gesture.confidence, 0.55, accuracy: 0.0001)
        XCTAssertTrue(gesture.isDouble)
        XCTAssertEqual(gesture.zone, .leftTop)
    }

    func testSlowSecondTapBecomesTwoSingles() {
        var resolver = TapGestureResolver(window: 0.4)
        _ = resolver.register(event(.leftTop, 0), supportsDouble: true)
        // Second tap arrives after the window: the first resolves as single, and
        // the second starts a fresh buffered sequence.
        let gestures = resolver.register(event(.leftTop, 0.7), supportsDouble: true)
        XCTAssertEqual(gestures, [.single(event(.leftTop, 0))])
        XCTAssertEqual(resolver.pendingEvent, event(.leftTop, 0.7))
    }

    func testDifferentZoneTapResolvesPreviousPendingAsSingle() {
        var resolver = TapGestureResolver(window: 0.4)
        _ = resolver.register(event(.leftTop, 0), supportsDouble: true)
        let gestures = resolver.register(event(.rightTop, 0.1), supportsDouble: true)
        XCTAssertEqual(gestures, [.single(event(.leftTop, 0))])
        XCTAssertEqual(resolver.pendingEvent, event(.rightTop, 0.1))
    }

    func testConfidenceGateAcceptsGestureConfidence() {
        XCTAssertTrue(LocalActionDispatchPolicy.allowsAutomaticDispatch(confidence: 0.8, action: .runShellCommand, isDeskActive: true))
        XCTAssertFalse(LocalActionDispatchPolicy.allowsAutomaticDispatch(confidence: 0.4, action: .runShellCommand, isDeskActive: true))
        XCTAssertFalse(LocalActionDispatchPolicy.allowsAutomaticDispatch(confidence: 0.8, action: .sound, isDeskActive: false))
    }
}
