import SwiftUI
import AppKit
import Pow
import Defaults
import Inject

struct ContentView: View {
    @Default(.profiles) private var profiles
    @ObserveInjection private var inject
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // состояние формы сохраняется между запусками
    @AppStorage("lang") private var lang: Lang = .en
    @AppStorage("direction") private var direction: Direction = .upload
    @AppStorage("userHost") private var userHost = defaultProfiles.first?.userHost ?? ""
    @AppStorage("port") private var port = defaultProfiles.first?.port ?? "22"
    @AppStorage("localPath") private var localPath = ""
    @AppStorage("remotePath") private var remotePath = defaultProfiles.first?.remotePath ?? "~/"
    @AppStorage("flagA") private var flagA = true
    @AppStorage("flagV") private var flagV = true
    @AppStorage("flagC") private var flagC = true

    @State private var excludes: [ExcludeItem] = defaultExcludes
    @State private var newExclude = ""
    @State private var copied = false
    @State private var dropLocal = false
    @State private var startPulse = 0
    @StateObject private var terminal = TerminalWindow()
    @FocusState private var focus: Field?

    private enum Field { case server, port, local, remote, newExclude }

    private var s: L10n { .of(lang) }
    private var localLabel: String { direction == .upload ? s.sourceLocal : s.destLocal }
    private var remoteLabel: String { direction == .upload ? s.destServer : s.sourceServer }

    // команда полна, только когда заданы сервер и оба пути
    private var isComplete: Bool {
        !userHost.trimmingCharacters(in: .whitespaces).isEmpty
            && !localPath.trimmingCharacters(in: .whitespaces).isEmpty
            && !remotePath.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var command: String {
        buildCommand(
            direction: direction, flagA: flagA, flagV: flagV, flagC: flagC,
            port: port, excludes: excludes, localPath: localPath,
            userHost: userHost, remotePath: remotePath
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            form
            Divider()
            commandBar
        }
        .frame(minWidth: 540, idealWidth: 640, maxWidth: .infinity,
               minHeight: 600, idealHeight: 640, maxHeight: .infinity)
        .onAppear {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            focus = .server
        }
        .focusedSceneValue(\.rsyncActions, RsyncActions(
            run: runCommand, copy: copy, save: saveCurrentAsProfile, clear: clearFields, canRun: isComplete
        ))
        .enableInjection()
    }

    private var form: some View {
        Form {
            Section {
                Picker("", selection: $direction) {
                    Label(s.upload, systemImage: "arrow.up.circle").tag(Direction.upload)
                    Label(s.download, systemImage: "arrow.down.circle").tag(Direction.download)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Section(s.serverSection) {
                HStack(spacing: 6) {
                    TextField("user@host", text: $userHost)
                        .focused($focus, equals: .server)
                    Menu {
                        ForEach(profiles) { p in
                            Button(p.name) {
                                userHost = p.userHost
                                port = p.port
                                remotePath = p.remotePath
                            }
                        }
                    } label: { Image(systemName: "chevron.down") }
                        .frame(width: 36)
                        .accessibilityLabel(s.serverProfiles)
                    Button(s.saveButton) { saveCurrentAsProfile() }
                        .help(s.saveHelp)
                }
                TextField(s.portPlaceholder, text: $port)
                    .focused($focus, equals: .port)
                    .frame(width: 120)
                    .onChange(of: port) { _, new in
                        let digits = new.filter(\.isNumber)
                        if digits != new { port = digits }
                    }
            }

            Section(s.pathsSection) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localLabel).font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        TextField(s.localPlaceholder, text: $localPath, axis: .vertical)
                            .lineLimit(1...3)
                            .focused($focus, equals: .local)
                            .help(s.localHelp)
                        Button(s.browse) { browse() }.help(s.browseHelp)
                    }
                    .padding(6)
                    .background(dropLocal ? Color.accentColor.opacity(0.15) : .clear)
                    .overlay(dropBorder)
                    .dropDestination(for: URL.self) { urls, _ in
                        guard let u = urls.first else { return false }
                        localPath = u.path
                        return true
                    } isTargeted: { dropLocal = $0 }
                    if localPath.isEmpty {
                        Text(s.localTip)
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(remoteLabel).font(.caption).foregroundStyle(.secondary)
                    TextField(s.remotePlaceholder, text: $remotePath, axis: .vertical)
                        .lineLimit(1...3)
                        .focused($focus, equals: .remote)
                        .help(s.remoteHelp)
                }
            }

            Section(s.optionsSection) {
                LabeledContent(s.flags) {
                    HStack(spacing: 14) {
                        Toggle("-a", isOn: $flagA)
                            .accessibilityLabel(s.flagAA11y).help(s.flagAHelp)
                        Toggle("-v", isOn: $flagV)
                            .accessibilityLabel(s.flagVA11y).help(s.flagVHelp)
                        Toggle("-c", isOn: $flagC)
                            .accessibilityLabel(s.flagCA11y).help(s.flagCHelp)
                    }
                    .toggleStyle(.checkbox)
                }
                excludesView
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }

    private var excludesView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(s.excludeSection).font(.caption).foregroundStyle(.secondary)
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                alignment: .leading, spacing: 4
            ) {
                ForEach($excludes) { $ex in
                    Toggle(ex.pattern, isOn: $ex.on).lineLimit(1)
                }
            }
            .toggleStyle(.checkbox)
            HStack(spacing: 6) {
                TextField(s.excludePlaceholder, text: $newExclude)
                    .focused($focus, equals: .newExclude)
                Button { addExclude() } label: { Image(systemName: "plus") }
                    .disabled(newExclude.trimmingCharacters(in: .whitespaces).isEmpty)
                    .help(s.addExcludeHelp)
            }
        }
    }

    private var commandBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.vertical) {
                Text(command.isEmpty ? " " : command)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(10)
            }
            .frame(minHeight: 54, maxHeight: 130)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator))

            HStack {
                if !isComplete {
                    Label(s.incompleteWarning, systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { copy() } label: {
                    Label(copied ? s.copied : s.copy, systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.glass)
                .help(s.copyHelp)
                .changeEffect(.spray(origin: UnitPoint(x: 0.5, y: 0)) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }, value: copied, isEnabled: copied && !reduceMotion)

                Button { runCommand() } label: {
                    Label(s.run, systemImage: "play.fill")
                }
                .buttonStyle(.glassProminent)
                .disabled(!isComplete)
                .help(s.runHelp)
                .changeEffect(.shine(duration: 0.7), value: startPulse, isEnabled: !reduceMotion)
            }
        }
        .padding(14)
        .background(.bar)
    }

    // пунктирная рамка drop-зоны (контрастнее при наведении)
    private var dropBorder: some View {
        RoundedRectangle(cornerRadius: 6)
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
            .foregroundStyle(dropLocal ? Color.accentColor : Color.secondary.opacity(0.7))
    }

    private func runCommand() {
        startPulse += 1
        terminal.run(command: command)
    }

    private func addExclude() {
        let p = newExclude.trimmingCharacters(in: .whitespaces)
        guard !p.isEmpty else { return }
        excludes.append(ExcludeItem(pattern: p, on: true))
        newExclude = ""
    }

    private func browse() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            localPath = url.path
        }
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
    }

    // сброс полей к примерам-плейсхолдерам
    private func clearFields() {
        userHost = defaultProfiles.first?.userHost ?? ""
        port = defaultProfiles.first?.port ?? "22"
        localPath = ""
        remotePath = defaultProfiles.first?.remotePath ?? "~/"
    }

    // @Default сохраняет автоматически при мутации массива
    private func saveCurrentAsProfile() {
        let name = userHost.split(separator: "@").first.map(String.init) ?? userHost
        let profile = ServerProfile(name: name, userHost: userHost, port: port, remotePath: remotePath)
        if let idx = profiles.firstIndex(where: { $0.userHost == userHost }) {
            profiles[idx] = profile
        } else {
            profiles.append(profile)
        }
    }
}

@main
struct RsyncBuilderApp: App {
    @AppStorage("lang") private var lang: Lang = .en

    var body: some Scene {
        WindowGroup("rsync builder") {
            ContentView()
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About rsync builder") { showAboutPanel() }
            }
            CommandMenu(L10n.of(lang).commandMenu) {
                RsyncCommands()
            }
        }

        Settings {
            SettingsView()
        }
    }
}
