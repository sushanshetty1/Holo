import XCTest
@testable import HoloCore

final class MenuBarStatusTests: XCTestCase {
    func testListeningWithProfile() {
        let status = MenuBarStatus(
            isListening: true,
            hasProfile: true,
            isGuidedSessionActive: false,
            lastZone: .leftBottom,
            statusMessage: "Listening for desk taps"
        )
        XCTAssertEqual(status.activity, .listening)
        XCTAssertEqual(status.pauseTitle, "Pause Listening")
        XCTAssertEqual(status.lastTapText, "Last tap: Left Front")
        XCTAssertEqual(status.statusText, "Listening for desk taps")
        XCTAssertTrue(status.canRecalibrate)
    }

    func testPausedWithProfileAndNoTapYet() {
        let status = MenuBarStatus(
            isListening: false,
            hasProfile: true,
            isGuidedSessionActive: false,
            lastZone: nil,
            statusMessage: "Paused"
        )
        XCTAssertEqual(status.activity, .paused)
        XCTAssertEqual(status.pauseTitle, "Resume Listening")
        XCTAssertEqual(status.lastTapText, "No taps yet")
        XCTAssertTrue(status.canRecalibrate)
    }

    func testNoProfileNeedsSetup() {
        let status = MenuBarStatus(
            isListening: false,
            hasProfile: false,
            isGuidedSessionActive: false,
            lastZone: nil,
            statusMessage: "Setup required • calibrate the four desk zones"
        )
        XCTAssertEqual(status.activity, .setupNeeded)
        XCTAssertEqual(status.pauseTitle, "Set Up Desk")
        XCTAssertFalse(status.canRecalibrate)
    }

    func testGuidedSessionDisablesRecalibrate() {
        let status = MenuBarStatus(
            isListening: true,
            hasProfile: true,
            isGuidedSessionActive: true,
            lastZone: .rightTop,
            statusMessage: "Calibration • Right Rear"
        )
        XCTAssertFalse(status.canRecalibrate)
        XCTAssertEqual(status.lastTapText, "Last tap: Right Rear")
    }

    func testListeningTakesPrecedenceForActivityWithoutProfile() {
        let status = MenuBarStatus(
            isListening: true,
            hasProfile: false,
            isGuidedSessionActive: false,
            lastZone: nil,
            statusMessage: "Listening • calibration needed"
        )
        XCTAssertEqual(status.activity, .listening)
        XCTAssertEqual(status.pauseTitle, "Pause Listening")
    }
}
