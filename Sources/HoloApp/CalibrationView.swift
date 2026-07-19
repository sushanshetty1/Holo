import HoloCore
import SwiftUI

struct CalibrationView: View {
    @ObservedObject var model: AppModel
    @State private var showRejectionTraining = true

    var body: some View {
        Group {
            if let session = model.calibrationSession {
                activeCalibration(session)
            } else {
                setup
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HoloTheme.background)
    }

    // MARK: Setup

    private var setup: some View {
        HoloScreen(
            title: "Set up your desk",
            subtitle: "Ten clean taps in each of four broad zones. Spread them around each highlighted area so Holo learns the whole zone, not one point."
        ) {
            profileSection
            sensingSection
            checklistSection
            startSection
        }
    }

    private var profileSection: some View {
        HoloGroup("Profile") {
            VStack(alignment: .leading, spacing: 14) {
                profileField("Name", prompt: "My Desk", text: $model.calibrationDraft.name)
                profileField("Surface", prompt: "Wood, laminate, glass…", text: $model.calibrationDraft.surfaceDescription)
                profileField("MacBook position", prompt: "Centered, near the back edge…", text: $model.calibrationDraft.laptopPositionNote)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .holoCard()
        }
    }

    private func profileField(_ label: String, prompt: String, text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 13))
                .frame(width: 140, alignment: .leading)
            TextField(label, text: text, prompt: Text(prompt))
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
        }
    }

    private var sensingSection: some View {
        HoloGroup("Sensing") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Approach")
                        .font(.system(size: 13))
                    Spacer()
                    Picker("", selection: $model.calibrationDraft.strategy) {
                        ForEach(SensingStrategy.allCases) { strategy in
                            Text(strategy.displayName).tag(strategy)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 190)
                }
                Text(model.calibrationDraft.strategy.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if model.calibrationDraft.strategy != .passive {
                    Label("Uses a quiet repeating speaker chirp", systemImage: "speaker.wave.2")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .holoCard()
        }
    }

    private var checklistSection: some View {
        HoloGroup("Before calibration") {
            VStack(alignment: .leading, spacing: 12) {
                checklistRow("Put the MacBook where it normally stays", systemImage: "macbook")
                checklistRow("Clear objects and cables that touch the MacBook", systemImage: "rectangle.dashed")
                checklistRow("Use one finger and a similar natural force, but vary the position within each zone", systemImage: "hand.tap")
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .holoCard()
        }
    }

    private func checklistRow(_ text: String, systemImage: String) -> some View {
        Label {
            Text(text).font(.system(size: 13))
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var startSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let comparison = model.applicableApproachComparison {
                Label(
                    "The latest diagnostics comparison selected \(comparison.selectedStrategy.displayName).",
                    systemImage: "checkmark.circle"
                )
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            } else {
                Label(
                    model.selectedProfile == nil
                        ? "Passive sensing is selected until you compare approaches in Diagnostics."
                        : "This profile keeps its saved approach until you compare approaches on this desk.",
                    systemImage: "info.circle"
                )
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                if let profile = model.selectedProfile {
                    Button("Recalibrate \(profile.name)") {
                        model.beginCalibration(draft: model.calibrationDraft, recalibrating: profile)
                    }
                    .holoPrimaryButton()
                    .controlSize(.large)

                    Button("Create New Profile") {
                        model.beginCalibration(draft: model.calibrationDraft)
                    }
                    .holoSecondaryButton()
                } else {
                    Button("Begin Calibration") {
                        model.beginCalibration(draft: model.calibrationDraft)
                    }
                    .holoPrimaryButton()
                    .controlSize(.large)
                }
            }
            .disabled(model.calibrationDraft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .holoCard()
    }

    // MARK: Active calibration

    private func activeCalibration(_ session: CalibrationSession) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                calibrationHeader(session)

                ProgressView(value: session.progress)

                DeskMapView(
                    activeZone: nil,
                    targetZone: session.currentZone,
                    confidence: 0,
                    signalStrength: model.audio.liveLevel,
                    isListening: model.audio.isListening,
                    counts: DeskZone.allCases.map { session.count(for: $0) }
                )
                .frame(maxWidth: 760)

                if session.zonesComplete {
                    completionControls(session)
                } else {
                    zoneControls(session)
                }
            }
            .frame(maxWidth: 820)
            .padding(HoloTheme.Space.screenPadding)
            .frame(maxWidth: .infinity)
        }
    }

    private func calibrationHeader(_ session: CalibrationSession) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 5) {
                Text(session.zonesComplete ? "All zones captured" : session.currentZone?.displayName ?? "Calibration")
                    .font(.system(size: 26, weight: .bold))
                Text(session.zonesComplete ? "Save the profile, then assign actions." : instruction(for: session))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 16)
            Text("\(session.positiveSamples.count) of \(session.totalRequired)")
                .font(.system(size: 13).monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func zoneControls(_ session: CalibrationSession) -> some View {
        VStack(spacing: 16) {
            if session.isSettling {
                HStack(spacing: 9) {
                    ProgressView()
                        .controlSize(.small)
                    Text(settlingMessage(for: session))
                        .font(.system(size: 15, weight: .semibold))
                }
            } else if session.isArmed {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.red)
                        .frame(width: 7, height: 7)
                    Text("Listening for this zone")
                        .font(.system(size: 15, weight: .semibold))
                    if let zone = session.currentZone {
                        Text("Tap \(session.count(for: zone) + 1) of \(session.targetPerZone)")
                            .font(.system(size: 13).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            } else if let zone = session.currentZone {
                Text("Move your hand to the \(zone.displayName.lowercased()) area. Holo ignores all sounds until you arm the zone.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Arm \(zone.displayName)") {
                    model.armCalibrationZone()
                }
                .holoPrimaryButton()
                .controlSize(.large)
                .disabled(!model.audio.isListening)
                .help(model.audio.isListening ? "Start collecting this zone" : "Resume the microphone before arming")
            }

            if let issue = model.guidedCaptureIssue {
                Label(issue.guidance, systemImage: "arrow.counterclockwise.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let quality = model.audio.diagnostics.latestSignalQuality {
                HStack(spacing: 18) {
                    Label(quality.summary, systemImage: quality.score > 0.48 ? "checkmark.circle" : "exclamationmark.circle")
                    Text(String(format: "%.1f dB SNR", quality.signalToNoiseDB))
                    Text(String(format: "%.3f peak", quality.peakAmplitude))
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }

            HStack {
                Button("Undo", systemImage: "arrow.uturn.backward") {
                    model.undoLastCalibrationTap()
                }
                .holoSecondaryButton()
                .disabled(session.positiveSamples.isEmpty)

                Button("Redo Zone", systemImage: "arrow.counterclockwise") {
                    model.retryCalibrationZone()
                }
                .holoSecondaryButton()
                .disabled(session.positiveSamples.isEmpty)

                Spacer()

                Button("Cancel", role: .cancel) {
                    model.cancelCalibration()
                }
            }
        }
        .padding(16)
        .frame(maxWidth: 760)
        .holoCard()
    }

    private func completionControls(_ session: CalibrationSession) -> some View {
        let weakest = model.calibrationValidation.flatMap { weakestResult(in: $0) }
        let needsReview = (model.calibrationValidation?.accuracy ?? 1) < CalibrationGuidance.minimumCleanAgreement

        return VStack(alignment: .leading, spacing: 16) {
            if let validation = model.calibrationValidation {
                consistencyReview(validation)
                Divider()
            }

            HStack {
                if needsReview, let weakest {
                    Button("Redo \(weakest.zone.displayName)") {
                        model.retryCalibrationZone(weakest.zone)
                    }
                    .holoPrimaryButton()
                    .controlSize(.large)

                    Menu("Save Anyway") {
                        Button("Save and Set Actions") {
                            model.finishCalibration(openActions: true)
                        }
                        Button("Save for Later") {
                            model.finishCalibration()
                        }
                    }
                    .holoSecondaryButton()
                } else {
                    Button("Save and Set Actions") {
                        model.finishCalibration(openActions: true)
                    }
                    .holoPrimaryButton()
                    .controlSize(.large)

                    Button("Save for Later") {
                        model.finishCalibration()
                    }
                    .holoSecondaryButton()
                }

                Spacer()
            }

            DisclosureGroup("Teach Holo sounds to reject (recommended)", isExpanded: $showRejectionTraining) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Capture Talking first: speak normally for a few seconds. Only speech peaks that reach the classifier are counted, and only acoustic features are saved.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(["Talking", "Typing", "Laptop touch", "Background noise"], id: \.self) { label in
                        HStack(spacing: 10) {
                            Button {
                                model.collectNegativeExamples(label: session.negativeLabel == label ? nil : label)
                            } label: {
                                Label(
                                    session.negativeLabel == label ? "Stop \(label)" : "Capture \(label)",
                                    systemImage: session.negativeLabel == label ? "stop.circle.fill" : "record.circle"
                                )
                            }
                            .holoSecondaryButton()
                            .disabled(!model.audio.isListening)
                            Text("\(session.negativeCount(for: label)) captured")
                                .font(.system(size: 12).monospacedDigit())
                                .foregroundStyle(.secondary)
                            if session.negativeCount(for: label) > 0 {
                                Button("Clear") {
                                    model.clearNegativeExamples(label: label)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
                .padding(.top, 10)
            }
        }
        .padding(16)
        .frame(maxWidth: 760)
        .holoCard()
    }

    private func consistencyReview(_ validation: CrossValidationResult) -> some View {
        let weakest = weakestResult(in: validation)
        let needsReview = validation.accuracy < CalibrationGuidance.minimumCleanAgreement

        return VStack(alignment: .leading, spacing: 8) {
            Label(
                "Calibration agreement: \(Int(validation.accuracy * 100))%",
                systemImage: needsReview ? "exclamationmark.triangle" : "checkmark.circle"
            )
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(needsReview ? Color.orange : Color.primary)

            Text("Each tap was classified while left out of training. This checks consistency; it is not the separate accuracy test.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if needsReview, let weakest {
                Text("Weakest zone: \(weakest.zone.displayName) · \(Int(weakest.accuracy * 100))%. Recapture it for a cleaner profile, or save anyway from the secondary menu.")
                    .font(.system(size: 13))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func weakestResult(in validation: CrossValidationResult) -> ZoneAccuracy? {
        validation.perZoneAccuracy.min { lhs, rhs in
            if lhs.accuracy == rhs.accuracy { return lhs.zone.rawValue < rhs.zone.rawValue }
            return lhs.accuracy < rhs.accuracy
        }
    }

    private func instruction(for session: CalibrationSession) -> String {
        guard session.currentZone != nil else { return "" }
        if session.isSettling {
            return "Move to the highlighted zone. Listening starts automatically."
        }
        if session.isArmed {
            return "Spread natural taps across the highlighted area and pause between taps."
        }
        return "Move to the highlighted zone, then arm it when ready."
    }

    private func settlingMessage(for session: CalibrationSession) -> String {
        guard let zone = session.currentZone else { return "Preparing…" }
        if session.positiveSamples.isEmpty {
            return "Preparing \(zone.displayName)…"
        }
        return "Move to \(zone.displayName) • listening starts automatically"
    }
}
