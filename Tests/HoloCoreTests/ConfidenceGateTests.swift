import XCTest
@testable import HoloCore

final class ConfidenceGateTests: XCTestCase {
    private func decision(_ confidence: Double, zone: DeskZone? = .leftTop, rejection: RejectionReason? = nil) -> ClassificationDecision {
        ClassificationDecision(
            zone: zone,
            confidence: confidence,
            signalStrength: 0.5,
            zoneDistances: [],
            rejectionReason: rejection
        )
    }

    func testBenignActionsUseBaseThreshold() {
        XCTAssertEqual(ZoneActionKind.none.minimumAutomaticConfidence, ClassifierDefaults.minimumConfidence)
        XCTAssertEqual(ZoneActionKind.sound.minimumAutomaticConfidence, ClassifierDefaults.minimumConfidence)
        XCTAssertEqual(ZoneActionKind.copyText.minimumAutomaticConfidence, ClassifierDefaults.minimumConfidence)
        XCTAssertEqual(ZoneActionKind.speakText.minimumAutomaticConfidence, ClassifierDefaults.minimumConfidence)
    }

    func testConsequentialActionsNeedMoreThanBase() {
        let consequential: [ZoneActionKind] = [.openURL, .runShortcut, .openApplication, .openItem, .screenshotClipboard, .screenshotSelection]
        for kind in consequential {
            XCTAssertGreaterThan(kind.minimumAutomaticConfidence, ClassifierDefaults.minimumConfidence, "\(kind) should require more than base confidence")
        }
    }

    func testShellCommandHasHighestBar() {
        XCTAssertGreaterThan(
            ZoneActionKind.runShellCommand.minimumAutomaticConfidence,
            ZoneActionKind.openURL.minimumAutomaticConfidence
        )
    }

    func testBorderlineTapRunsBenignButNotShell() {
        let borderline = decision(0.40) // accepted (>= base 0.36) but low
        XCTAssertTrue(LocalActionDispatchPolicy.allowsAutomaticDispatch(for: borderline, action: .sound, isDeskActive: true))
        XCTAssertFalse(LocalActionDispatchPolicy.allowsAutomaticDispatch(for: borderline, action: .runShellCommand, isDeskActive: true))
        XCTAssertFalse(LocalActionDispatchPolicy.allowsAutomaticDispatch(for: borderline, action: .openApplication, isDeskActive: true))
    }

    func testHighConfidenceRunsEverything() {
        let strong = decision(0.75)
        XCTAssertTrue(LocalActionDispatchPolicy.allowsAutomaticDispatch(for: strong, action: .runShellCommand, isDeskActive: true))
        XCTAssertTrue(LocalActionDispatchPolicy.allowsAutomaticDispatch(for: strong, action: .openURL, isDeskActive: true))
    }

    func testOffDeskBlocksEvenHighConfidence() {
        let strong = decision(0.95)
        XCTAssertFalse(LocalActionDispatchPolicy.allowsAutomaticDispatch(for: strong, action: .sound, isDeskActive: false))
    }

    func testRejectedDecisionBlocksEverything() {
        let rejected = decision(0.9, zone: nil, rejection: .ambiguousZone)
        XCTAssertFalse(LocalActionDispatchPolicy.allowsAutomaticDispatch(for: rejected, action: .sound, isDeskActive: true))
    }
}
