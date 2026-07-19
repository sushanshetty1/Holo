import HoloCore
import SwiftUI

struct LiveSurfaceView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Group {
            if model.selectedProfile == nil {
                setupPrompt
            } else {
                liveDesk
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HoloTheme.background)
    }

    private var liveDesk: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 24)

            DeskMapView(
                activeZone: model.activeZone,
                targetZone: nil,
                confidence: model.lastDecision?.confidence ?? 0,
                signalStrength: model.lastDecision?.signalStrength ?? model.audio.liveLevel,
                isListening: model.audio.isListening
            )
            .frame(maxWidth: 720, maxHeight: 470)
            .padding(.horizontal, 36)

            resultStrip

            Spacer(minLength: 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 28)
    }

    private var setupPrompt: some View {
        VStack(spacing: 16) {
            HoloLogoView(tint: .accentColor, listening: false)
                .frame(width: 56, height: 56)

            VStack(spacing: 8) {
                Text("Set up the desk around your MacBook")
                    .font(.system(size: 20, weight: .semibold))
                Text("Taps can't be assigned until Holo learns this desk. You'll tap ten times across each of four broad zones: rear and front on both sides of the MacBook.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
                Text("Microphone access is requested when calibration begins.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Button("Set Up Four Zones") {
                model.openSetup()
            }
            .holoPrimaryButton()
            .controlSize(.large)
            .padding(.top, 4)
        }
        .padding(40)
    }

    private var resultStrip: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 2) {
                Text(lastResultTitle)
                    .font(.system(size: 15, weight: .semibold))
                Text(model.lastDecision?.rejectionReason?.displayName ?? model.selectedProfile?.name ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 160, alignment: .leading)

            Divider().frame(height: 34)

            compactGauge("Confidence", value: model.lastDecision?.confidence ?? 0)
            compactGauge("Signal", value: model.lastDecision?.signalStrength ?? model.audio.liveLevel)

            if let latency = model.lastDecision?.processingLatencyMilliseconds, latency > 0 {
                Divider().frame(height: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "%.1f ms", latency))
                        .font(.system(size: 13, design: .monospaced))
                    Text("Processing")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button("Recalibrate", systemImage: "arrow.triangle.2.circlepath") {
                model.prepareRecalibration()
            }
            .holoSecondaryButton()
        }
        .padding(16)
        .frame(maxWidth: 720)
        .holoCard()
    }

    private var lastResultTitle: String {
        guard let decision = model.lastDecision else { return "Waiting for a tap" }
        return decision.zone?.displayName ?? "Tap rejected"
    }

    private func compactGauge(_ label: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text("\(Int(value * 100))%")
                    .monospacedDigit()
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            ProgressView(value: value)
                .frame(width: 112)
        }
    }
}
