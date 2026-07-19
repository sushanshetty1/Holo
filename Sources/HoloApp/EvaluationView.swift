import HoloCore
import SwiftUI

struct EvaluationView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Group {
            if model.selectedProfile == nil {
                noProfile
            } else if let session = model.evaluationSession {
                activeSession(session)
            } else if let report = model.latestEvaluation {
                reportView(report)
            } else {
                intro
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HoloTheme.background)
    }

    // MARK: No profile

    private var noProfile: some View {
        VStack(spacing: 18) {
            Spacer()
            HoloLogoView(tint: .secondary, listening: false)
                .frame(width: 64, height: 64)
            VStack(spacing: 8) {
                Text("No desk profile")
                    .font(.system(size: 20, weight: .semibold))
                Text("Calibrate the four desk zones before evaluating them.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
            Button("Open Calibration") { model.section = .calibrate }
                .holoPrimaryButton()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(36)
    }

    // MARK: Intro (idle)

    private var acceptanceRows: [HoloInfoRow] {
        [
            HoloInfoRow(
                label: "Taps",
                value: "\(DeskZone.allCases.count * EvaluationAcceptance.tapsPerZone) total · \(EvaluationAcceptance.tapsPerZone) per zone"
            ),
            HoloInfoRow(
                label: "Accuracy target",
                value: "\(Int(EvaluationAcceptance.minimumAccuracy * 100))% or better"
            ),
            HoloInfoRow(
                label: "Response target",
                value: "Median under \(Int(EvaluationAcceptance.maximumMedianResponseMilliseconds)) ms"
            ),
            HoloInfoRow(label: "Output", value: "Per-zone accuracy and confusion matrix")
        ]
    }

    private var intro: some View {
        HoloScreen(
            title: "Accuracy Test",
            subtitle: "Use new taps that were not part of calibration. Holo guides \(EvaluationAcceptance.tapsPerZone) taps in each zone and counts rejected taps as incorrect."
        ) {
            VStack(spacing: 18) {
                HoloLogoView(tint: .accentColor, listening: true)
                    .frame(width: 56, height: 56)
                Text("Test your calibration")
                    .font(.system(size: 17, weight: .semibold))
                Button("Start Accuracy Test") { model.beginEvaluation() }
                    .holoPrimaryButton()
                    .controlSize(.large)
            }
            .frame(maxWidth: .infinity)
            .padding(28)
            .holoCard()

            HoloGroup("What to expect") {
                HoloInfoCard(rows: acceptanceRows)
            }
        }
    }

    // MARK: Active guided run

    private func activeSession(_ session: EvaluationSession) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.currentZone?.displayName ?? "Complete")
                            .font(.system(size: 24, weight: .bold))
                        Text("Tap the highlighted zone naturally.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(session.records.count) of \(DeskZone.allCases.count * session.targetPerZone)")
                        .font(.system(size: 13).monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: session.progress)

                DeskMapView(
                    activeZone: model.activeZone,
                    targetZone: session.currentZone,
                    confidence: model.lastDecision?.confidence ?? 0,
                    signalStrength: model.lastDecision?.signalStrength ?? 0,
                    isListening: model.audio.isListening,
                    counts: DeskZone.allCases.map { zone in
                        session.records.filter { $0.expectedZone == zone }.count
                    }
                )
                .frame(maxWidth: 760)

                VStack(spacing: 16) {
                    if session.isSettling {
                        HStack(spacing: 9) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Preparing the microphone…")
                                .font(.system(size: 14, weight: .medium))
                        }
                    } else if session.isArmed {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(.red)
                                .frame(width: 7, height: 7)
                            Text("Accuracy test armed")
                                .font(.system(size: 14, weight: .semibold))
                            if let zone = session.currentZone {
                                let count = session.records.filter { $0.expectedZone == zone }.count
                                Text("Tap \(count + 1) of \(session.targetPerZone)")
                                    .font(.system(size: 12).monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else if let zone = session.currentZone {
                        Text("Move to \(zone.displayName.lowercased()). Sounds are ignored until you arm this zone.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Arm \(zone.displayName)") { model.armEvaluationZone() }
                            .holoPrimaryButton()
                            .controlSize(.large)
                            .disabled(!model.audio.isListening)
                            .help(model.audio.isListening ? "Start testing this zone" : "Resume the microphone before arming")
                    }

                    HStack(spacing: 20) {
                        let accuracy = session.records.isEmpty
                            ? 0
                            : Double(session.records.filter(\.isCorrect).count) / Double(session.records.count)
                        LabeledContent("Accuracy so far", value: "\(Int(accuracy * 100))%")
                        if let decision = model.lastDecision {
                            LabeledContent("Last result", value: decision.zone?.displayName ?? "Rejected")
                        }
                        Spacer()
                        Button("Cancel", role: .cancel) { model.cancelEvaluation() }
                    }
                    .font(.system(size: 13))
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .holoCard()
            }
            .frame(maxWidth: 820)
            .padding(32)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Results

    private func summaryRows(_ report: EvaluationReport) -> [HoloInfoRow] {
        [
            HoloInfoRow(
                label: "Overall accuracy",
                value: "\(Int(report.overallAccuracy * 100))% · \(report.meetsAccuracyTarget ? "Meets 80% target" : "Below 80% target")"
            ),
            HoloInfoRow(label: "Median response", value: latencySummary(report)),
            HoloInfoRow(
                label: "Balanced session",
                value: report.isBalancedAcceptanceSession
                    ? "\(DeskZone.allCases.count) × \(EvaluationAcceptance.tapsPerZone)"
                    : "No"
            ),
            HoloInfoRow(
                label: "Rejected taps",
                value: "\(report.records.filter { $0.predictedZone == nil }.count)",
                mono: true
            )
        ]
    }

    private func reportView(_ report: EvaluationReport) -> some View {
        HoloScreen(
            title: "Accuracy Test",
            subtitle: "\(report.profileName) · \(report.strategy.displayName)"
        ) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: report.meetsAccuracyAndLatencyTargets ? "checkmark.seal.fill" : "checkmark.seal")
                    .font(.system(size: 26))
                    .foregroundStyle(report.meetsAccuracyAndLatencyTargets ? Color.green : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(report.meetsAccuracyAndLatencyTargets ? "Accuracy test passed" : "Accuracy test complete")
                        .font(.system(size: 17, weight: .semibold))
                    Text(report.completedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Run Again") { model.beginEvaluation() }
                    .holoSecondaryButton()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .holoCard()

            HoloGroup("Summary") {
                HoloInfoCard(rows: summaryRows(report))
            }

            HoloGroup("Per-zone accuracy") {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                    GridRow {
                        Text("Zone").font(.system(size: 12)).foregroundStyle(.secondary)
                        Text("Correct").font(.system(size: 12)).foregroundStyle(.secondary)
                        Text("Accuracy").font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    ForEach(report.perZoneAccuracy) { item in
                        GridRow {
                            Text(item.zone.displayName)
                                .font(.system(size: 13))
                            Text("\(item.correct) / \(item.total)")
                                .font(.system(size: 13).monospacedDigit())
                            HStack(spacing: 10) {
                                ProgressView(value: item.accuracy)
                                    .frame(width: 150)
                                Text("\(Int(item.accuracy * 100))%")
                                    .font(.system(size: 12).monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .holoCard()
            }

            HoloGroup("Confusion matrix", footnote: "Rows are expected zones. Columns are predicted zones; R is rejected.") {
                confusionGrid(report)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .holoCard()
            }

            if model.latestEvaluationIsPersisted {
                Text("JSON and CSV reports are saved locally in Holo's Application Support folder.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                Label(
                    "This result is in memory only because its JSON and CSV files were not saved.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.system(size: 12))
                .foregroundStyle(.orange)
            }
        }
    }

    private func confusionGrid(_ report: EvaluationReport) -> some View {
        Grid(horizontalSpacing: 5, verticalSpacing: 5) {
            GridRow {
                Text("")
                ForEach(DeskZone.allCases) { zone in matrixLabel(zone.shortName) }
                matrixLabel("R")
            }
            ForEach(DeskZone.allCases) { expected in
                GridRow {
                    matrixLabel(expected.shortName)
                    ForEach(DeskZone.allCases) { predicted in
                        matrixCell(
                            report.confusionMatrix[expected.rawValue][predicted.rawValue],
                            diagonal: expected == predicted
                        )
                    }
                    matrixCell(report.rejectedPerZone[expected.rawValue], diagonal: false)
                }
            }
        }
    }

    // MARK: Helpers

    private func latencySummary(_ report: EvaluationReport) -> String {
        guard report.hasCompleteResponseLatency else {
            return "Unavailable · one or more timestamps were invalid"
        }
        return String(
            format: "%.0f ms · %@",
            report.medianResponseLatencyMilliseconds,
            report.meetsLatencyTarget ? "Under 200 ms target" : "At or above 200 ms target"
        )
    }

    private func matrixLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption2.monospaced().weight(.medium))
            .foregroundStyle(.secondary)
            .frame(width: 34, height: 22)
    }

    private func matrixCell(_ value: Int, diagonal: Bool) -> some View {
        Text("\(value)")
            .font(.caption.monospacedDigit())
            .frame(width: 34, height: 28)
            .background(
                (diagonal ? Color.green : Color.orange)
                    .opacity(value == 0 ? 0.04 : min(0.10 + Double(value) * 0.055, 0.48)),
                in: RoundedRectangle(cornerRadius: 5)
            )
    }
}
