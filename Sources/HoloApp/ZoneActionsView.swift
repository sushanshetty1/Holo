import AppKit
import HoloCore
import SwiftUI
import UniformTypeIdentifiers

struct ZoneActionsView: View {
    @ObservedObject var model: AppModel
    @State private var confirmDelete = false

    var body: some View {
        Group {
            if let profile = model.selectedProfile {
                HoloScreen(
                    title: "Assign actions",
                    subtitle: "Each accepted tap runs its assigned action. Changes save automatically."
                ) {
                    HoloGroup("Left of the MacBook") {
                        VStack(spacing: 12) {
                            ForEach(sortedConfigurations(profile, isLeft: true)) { configuration in
                                ZoneActionRow(
                                    configuration: configuration,
                                    onChange: { action in
                                        model.updateAction(for: configuration.zone, action: action)
                                    },
                                    onTest: model.testAction,
                                    onError: { error in
                                        model.errorMessage = "The action could not be assigned. \(error.localizedDescription)"
                                    }
                                )
                                .id("\(profile.id)-\(configuration.zone.rawValue)")
                            }
                        }
                    }

                    HoloGroup("Right of the MacBook") {
                        VStack(spacing: 12) {
                            ForEach(sortedConfigurations(profile, isLeft: false)) { configuration in
                                ZoneActionRow(
                                    configuration: configuration,
                                    onChange: { action in
                                        model.updateAction(for: configuration.zone, action: action)
                                    },
                                    onTest: model.testAction,
                                    onError: { error in
                                        model.errorMessage = "The action could not be assigned. \(error.localizedDescription)"
                                    }
                                )
                                .id("\(profile.id)-\(configuration.zone.rawValue)")
                            }
                        }
                    }

                    automationSection

                    profileSection(profile)
                }
            } else {
                emptyState
            }
        }
        .background(HoloTheme.background)
        .confirmationDialog("Delete this desk profile?", isPresented: $confirmDelete) {
            Button("Delete Profile", role: .destructive) { model.deleteSelectedProfile() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The saved calibration and its four actions will be removed.")
        }
    }

    // MARK: Automation guidance

    private var automationSection: some View {
        HoloGroup("Automation") {
            VStack(alignment: .leading, spacing: 12) {
                automationNote(
                    "Use Run Shortcut for multi-step workflows such as opening Claude and starting a voice workflow.",
                    systemImage: "command"
                )
                automationNote(
                    "Shell commands run through /bin/zsh with Holo's current macOS permissions.",
                    systemImage: "terminal"
                )
                automationNote(
                    "Screenshot actions copy the result and may request Screen Recording access.",
                    systemImage: "camera.viewfinder"
                )
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .holoCard()
        }
    }

    private func automationNote(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Profile

    private func profileSection(_ profile: HoloProfile) -> some View {
        HoloGroup("Profile") {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Active profile")
                        .font(.system(size: 13))
                    Spacer(minLength: 16)
                    Text(profile.name)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Button("Delete Profile", role: .destructive) {
                    confirmDelete = true
                }
                .holoSecondaryButton()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .holoCard()
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 18) {
            HoloLogoView(tint: .secondary, listening: false)
                .frame(width: 64, height: 64)
            VStack(spacing: 6) {
                Text("No desk profile yet")
                    .font(.system(size: 17, weight: .semibold))
                Text("Calibrate the four zones before assigning actions.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button("Open Calibration") { model.section = .calibrate }
                .holoPrimaryButton()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private func sortedConfigurations(_ profile: HoloProfile, isLeft: Bool) -> [ZoneConfiguration] {
        profile.zones
            .filter { $0.zone.isLeft == isLeft }
            .sorted { $0.zone.verticalIndex < $1.zone.verticalIndex }
    }
}

private struct ZoneActionRow: View {
    let configuration: ZoneConfiguration
    let onChange: (ZoneActionConfiguration) -> Bool
    let onTest: (ZoneActionConfiguration) -> Void
    let onError: (Error) -> Void
    @State private var action: ZoneActionConfiguration
    @State private var isRevertingFailedSave = false

    private let sounds = ["Tink", "Pop", "Ping", "Glass", "Funk", "Morse", "Purr", "Sosumi"]

    init(
        configuration: ZoneConfiguration,
        onChange: @escaping (ZoneActionConfiguration) -> Bool,
        onTest: @escaping (ZoneActionConfiguration) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        self.configuration = configuration
        self.onChange = onChange
        self.onTest = onTest
        self.onError = onError
        _action = State(initialValue: configuration.action)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(configuration.zone.positionName)
                    .font(.system(size: 15, weight: .semibold))
                Text(configuration.zone.isLeft ? "Left side" : "Right side")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 12)
                Button("Test", systemImage: "play.fill") {
                    onTest(action)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .disabled(!canTest)
                .help(canTest ? "Test this action" : "Finish configuring this action before testing")
            }

            HStack(spacing: 12) {
                Text("Action")
                    .font(.system(size: 13))
                Spacer(minLength: 16)
                Picker("Action", selection: $action.kind) {
                    ForEach(ZoneActionKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .labelsHidden()
                .frame(width: 200)
            }

            detailControl
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .holoCard()
        .onChange(of: action) { oldValue, newValue in
            if isRevertingFailedSave {
                isRevertingFailedSave = false
                return
            }
            if !onChange(newValue) {
                isRevertingFailedSave = true
                action = oldValue
            }
        }
    }

    private var canTest: Bool {
        LocalActionPlanner.command(for: action) != nil
    }

    @ViewBuilder
    private var detailControl: some View {
        switch action.kind {
        case .none:
            Text("Highlight only")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        case .sound:
            Picker("Sound", selection: $action.soundName) {
                ForEach(sounds, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
            .frame(maxWidth: 180)
        case .copyText:
            TextField("Text to copy", text: $action.text)
        case .speakText:
            TextField("Words to speak", text: $action.text)
        case .openURL:
            TextField("Website address", text: $action.text, prompt: Text("https://example.com"))
        case .runShortcut:
            TextField("Shortcut name", text: $action.text, prompt: Text("Start Claude listening"))
        case .openApplication:
            Button {
                chooseApplication()
            } label: {
                Label(action.text.isEmpty ? "Choose Application…" : action.text, systemImage: "app")
                    .lineLimit(1)
            }
            .holoSecondaryButton()
        case .openItem:
            Button {
                chooseItem()
            } label: {
                Label(action.text.isEmpty ? "Choose File or Folder…" : action.text, systemImage: "doc")
                    .lineLimit(1)
            }
            .holoSecondaryButton()
        case .runShellCommand:
            VStack(alignment: .leading, spacing: 3) {
                TextField("Shell command", text: $action.text, prompt: Text("open -a Claude"))
                    .font(.system(.body, design: .monospaced))
                Text("Runs automatically after an accepted tap")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
            }
        case .screenshotClipboard:
            Label("All displays → Clipboard", systemImage: "rectangle.on.rectangle")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        case .screenshotSelection:
            Label("Choose an area → Clipboard", systemImage: "viewfinder")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    private func chooseApplication() {
        let panel = NSOpenPanel()
        panel.title = "Choose an application"
        panel.prompt = "Assign"
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        saveBookmark(for: url, displayName: url.deletingPathExtension().lastPathComponent)
    }

    private func chooseItem() {
        let panel = NSOpenPanel()
        panel.title = "Choose a file or folder"
        panel.prompt = "Assign"
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        saveBookmark(for: url, displayName: url.lastPathComponent)
    }

    private func saveBookmark(for url: URL, displayName: String) {
        do {
            action.bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            action.text = displayName
        } catch {
            action.bookmarkData = nil
            action.text = ""
            onError(error)
        }
    }
}
