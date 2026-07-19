import XCTest
@testable import HoloCore

final class ClassifierAdaptationTests: XCTestCase {
    func testAddingExampleGrowsThatZoneAndKeepsSummaryConsistent() throws {
        let base = try TrainedTapClassifier.train(positiveExamples: trainingSamples())
        let baseRightBottom = base.positiveExamples.filter { $0.zone == .rightBottom }.count

        let result = try ClassifierAdaptation.addingExample(
            feature(zone: .rightBottom, jitter: 0.006),
            zone: .rightBottom,
            to: base
        )

        XCTAssertEqual(result.classifier.positiveExamples.count, base.positiveExamples.count + 1)
        XCTAssertEqual(result.summary.samplesPerZone[DeskZone.rightBottom.rawValue], baseRightBottom + 1)
        // Summary must stay internally consistent (ProfileStore validates this).
        XCTAssertEqual(result.summary.sampleCount, result.summary.samplesPerZone.reduce(0, +))
        XCTAssertEqual(result.summary.sampleCount, result.classifier.positiveExamples.count)
    }

    func testCorrectedExampleClassifiesAsItsZone() throws {
        let base = try TrainedTapClassifier.train(positiveExamples: trainingSamples())
        let corrected = feature(zone: .leftBottom, jitter: 0.004)
        let result = try ClassifierAdaptation.addingExample(corrected, zone: .leftBottom, to: base)
        XCTAssertEqual(result.classifier.predict(corrected).zone, .leftBottom)
    }

    func testAdaptationPreservesNegativeExamples() throws {
        let base = try TrainedTapClassifier.train(
            positiveExamples: trainingSamples(),
            negativeExamples: [LabeledTap(zone: nil, negativeLabel: "Talking", feature: feature(zone: .leftTop, jitter: 5))]
        )
        let result = try ClassifierAdaptation.addingExample(feature(zone: .rightTop), zone: .rightTop, to: base)
        XCTAssertEqual(result.classifier.negativeExamples.count, base.negativeExamples.count)
    }

    // MARK: Helpers (mirror ClassifierTests' synthetic features)

    private func trainingSamples() -> [LabeledTap] {
        DeskZone.allCases.flatMap { zone in
            (0..<8).map { sample in
                LabeledTap(zone: zone, feature: feature(zone: zone, jitter: Double(sample - 3) * 0.012))
            }
        }
    }

    private func feature(zone: DeskZone, jitter: Double = 0) -> TapFeatureVector {
        TapFeatureVector(
            strategy: .passive,
            names: ["row", "column", "diagonal", "texture"],
            values: [
                Double(zone.row) * 2.2 + jitter,
                Double(zone.column) * 2.0 - jitter,
                Double(zone.row + zone.column) * 0.8 + jitter * 0.5,
                Double(zone.rawValue) * 0.35 - jitter * 0.2
            ],
            quality: SignalQuality(
                signalToNoiseDB: 28,
                peakAmplitude: 0.12,
                rmsAmplitude: 0.025,
                clippingFraction: 0,
                noiseFloorRMS: 0.0004,
                durationMilliseconds: 90
            )
        )
    }
}
