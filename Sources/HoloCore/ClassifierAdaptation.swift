import Foundation

/// Incremental, on-device adaptation: fold a corrected live tap back into a
/// trained classifier and retrain.
///
/// Clean calibration taps and real live taps differ, and marginal separability
/// (50–79% agreement) is where that gap hurts most. Letting the user correct a
/// misread tap adds a real-condition example exactly where the model is weak,
/// which is more effective than re-tuning thresholds blind.
public enum ClassifierAdaptation {
    public struct Result: Equatable, Sendable {
        public let classifier: TrainedTapClassifier
        public let summary: CalibrationSummary
    }

    /// Adds `feature` as a positive example for `zone` and retrains. Returns the
    /// new classifier plus a matching calibration summary (recomputed per-zone
    /// counts and leave-one-out agreement) so the saved profile stays internally
    /// consistent with `ProfileStore`'s validation.
    public static func addingExample(
        _ feature: TapFeatureVector,
        zone: DeskZone,
        to classifier: TrainedTapClassifier
    ) throws -> Result {
        let example = LabeledTap(zone: zone, feature: feature)
        let retrained = try TrainedTapClassifier.train(
            positiveExamples: classifier.positiveExamples + [example],
            negativeExamples: classifier.negativeExamples,
            minimumConfidence: classifier.minimumConfidence
        )
        let counts = DeskZone.allCases.map { candidate in
            retrained.positiveExamples.filter { $0.zone == candidate }.count
        }
        let agreement = (try? ClassifierEvaluator.leaveOneOut(
            retrained.positiveExamples,
            minimumConfidence: retrained.minimumConfidence
        ))?.accuracy
        let summary = CalibrationSummary(
            sampleCount: retrained.positiveExamples.count,
            samplesPerZone: counts,
            leaveOneOutAccuracy: agreement
        )
        return Result(classifier: retrained, summary: summary)
    }
}
