import HoloCore
import SwiftUI

struct RootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        NavigationSplitView {
            List(selection: $model.section) {
                sidebarHeader
                    .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 14, trailing: 8))
                    .listRowSeparator(.hidden)
                    .selectionDisabled()

                Section {
                    ForEach(AppSection.primary) { navigationRow($0) }
                }

                Section("Advanced") {
                    ForEach(AppSection.advanced) { navigationRow($0) }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 216, ideal: 240, max: 268)
            .safeAreaInset(edge: .bottom, spacing: 0) { statusCard }
        } detail: {
            content
        }
        .navigationSplitViewStyle(.balanced)
        .alert("Holo", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "Unknown error")
        }
    }

    // MARK: Sidebar header (logo + profile switcher)

    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                HoloLogoView(tint: .accentColor, listening: model.audio.isListening)
                    .frame(width: 22, height: 22)
                Text("Holo")
                    .font(.system(size: 16, weight: .semibold))
                Spacer(minLength: 0)
            }
            profileSwitcher
        }
    }

    @ViewBuilder
    private var profileSwitcher: some View {
        if model.profiles.isEmpty {
            Button {
                model.openSetup()
            } label: {
                chip(icon: "scope", text: "Set up desk", trailing: "chevron.right")
            }
            .buttonStyle(.plain)
            .disabled(model.guidedSection != nil)
        } else {
            Menu {
                ForEach(model.profiles) { profile in
                    Button {
                        model.selectProfile(profile.id)
                    } label: {
                        if profile.id == model.selectedProfileID {
                            Label(profile.name, systemImage: "checkmark")
                        } else {
                            Text(profile.name)
                        }
                    }
                }
            } label: {
                chip(icon: "macbook", text: model.selectedProfile?.name ?? "Profile", trailing: "chevron.up.chevron.down")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .disabled(model.guidedSection != nil)
            .help("Choose a desk profile")
        }
    }

    private func chip(icon: String, text: String, trailing: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 4)
            Image(systemName: trailing)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.holoCard.opacity(0.7)))
        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Color.holoSeparator, lineWidth: 1))
        .contentShape(Rectangle())
    }

    private func navigationRow(_ section: AppSection) -> some View {
        Label(section.title, systemImage: section.symbol)
            .tag(section)
            .disabled(!model.canNavigate(to: section))
    }

    // MARK: Detail content

    @ViewBuilder
    private var content: some View {
        switch model.section {
        case .live:
            LiveSurfaceView(model: model)
        case .calibrate:
            CalibrationView(model: model)
        case .diagnostics:
            DiagnosticsView(model: model)
        case .evaluate:
            EvaluationView(model: model)
        case .actions:
            ZoneActionsView(model: model)
        }
    }

    // MARK: Pinned status card

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Circle()
                    .fill(stateColor)
                    .frame(width: 7, height: 7)
                Text(stateTitle)
                    .font(.system(size: 12, weight: .semibold))
                Spacer(minLength: 4)
                Button(action: model.togglePause) {
                    Image(systemName: model.audio.isListening ? "pause.fill" : "play.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 26, height: 22)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.accentColor.opacity(0.15)))
                }
                .buttonStyle(.plain)
                .help(model.audio.isListening ? "Pause listening" : "Resume listening")
            }

            Text(model.statusMessage)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            levelMeter

            privacyBadge
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.holoFooter))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.holoSeparator, lineWidth: 1))
        .padding(12)
    }

    private var levelMeter: some View {
        Capsule()
            .fill(Color.holoSeparator)
            .frame(height: 4)
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    Capsule()
                        .fill(model.audio.isListening ? Color.accentColor : Color.secondary)
                        .frame(width: max(4, geo.size.width * min(max(model.audio.liveLevel, 0), 1)))
                }
            }
            .frame(height: 4)
    }

    @ViewBuilder
    private var privacyBadge: some View {
        if model.debugRecordingEnabled {
            badge("record.circle", "Debug recording on", .red)
        } else if model.audio.isListening && model.audio.strategy != .passive {
            badge("speaker.wave.1", "Speaker probe active", .secondary)
        } else if model.hasDebugRecordings {
            badge("externaldrive", "Saved debug audio", .orange)
        } else {
            badge("lock", "Audio discarded", .secondary)
        }
    }

    private func badge(_ icon: String, _ text: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 10.5))
            Spacer(minLength: 0)
        }
        .foregroundStyle(color)
    }

    private var needsInitialSetup: Bool {
        model.selectedProfile == nil && model.calibrationSession == nil
    }

    private var stateColor: Color {
        if model.audio.isListening { return .green }
        return needsInitialSetup ? .orange : .secondary
    }

    private var stateTitle: String {
        if model.audio.isListening { return "Listening" }
        return needsInitialSetup ? "Setup needed" : "Paused"
    }
}
