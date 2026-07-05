import AppKit
import Defaults
import Pow
import SwiftUI

struct ContentView: View {
    @Default(.profiles) private var profiles
    @Default(.excludes) private var excludes
    @EnvironmentObject private var updater: UpdateChecker
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openURL) private var openURL

    // состояние формы сохраняется между запусками
    @AppStorage("lang") private var lang: Lang = .systemDefault
    @AppStorage("direction") private var direction: Direction = .upload
    @AppStorage("userHost") private var userHost = defaultProfiles.first?.userHost ?? ""
    @AppStorage("port") private var port = defaultProfiles.first?.port ?? "22"
    @AppStorage("localPath") private var localPath = ""
    @AppStorage("remotePath") private var remotePath = defaultProfiles.first?.remotePath ?? "~/"
    @AppStorage("flagA") private var flagA = true
    @AppStorage("flagV") private var flagV = true
    @AppStorage("flagC") private var flagC = false
    @AppStorage("optCompress") private var optCompress = false
    @AppStorage("optProgress") private var optProgress = false
    @AppStorage("optUpdate") private var optUpdate = false
    @AppStorage("optDelete") private var optDelete = false
    @AppStorage("optStats") private var optStats = false
    @AppStorage("optBwlimit") private var optBwlimit = ""
    @AppStorage("optNoOwner") private var optNoOwner = false
    @AppStorage("optMkpath") private var optMkpath = false
    @AppStorage("optChmod") private var optChmod = ""
    @AppStorage("optSudo") private var optSudo = false
    @AppStorage("optPostCmd") private var optPostCmd = ""
    @AppStorage("lastUpdateCheckAt") private var lastUpdateCheckAt = 0.0

    // пароль держим только в памяти (не @AppStorage) - на диск не пишем
    @State private var password = ""
    @State private var newExclude = ""
    @State private var copied = false
    @State private var importNotice: String?
    @State private var dropLocal = false
    @State private var startPulse = 0
    @State private var showExcludes = false
    @State private var showOptions = false
    @StateObject private var runner = CommandRunner()
    @StateObject private var terminal = TerminalWindow()
    @FocusState private var focus: Field?

    private enum Field { case server, port, password, local, remote, newExclude }

    private var s: L10n { .of(lang) }
    private var localLabel: String { direction == .upload ? s.sourceLocal : s.destLocal }
    private var remoteLabel: String { direction == .upload ? s.destServer : s.sourceServer }

    private var enabledExcludeCount: Int {
        excludes.filter { $0.on && !$0.pattern.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }

    // команда полна, только когда заданы сервер и оба пути
    private var isComplete: Bool {
        !userHost.trimmingCharacters(in: .whitespaces).isEmpty
            && !localPath.trimmingCharacters(in: .whitespaces).isEmpty
            && !remotePath.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var options: RsyncOptions {
        RsyncOptions(
            archive: flagA, verbose: flagV, checksum: flagC,
            compress: optCompress, progress: optProgress, update: optUpdate,
            delete: optDelete, stats: optStats, dryRun: false, bwlimit: optBwlimit,
            noOwnerGroup: optNoOwner, mkpath: optMkpath, chmod: optChmod, sudo: optSudo,
            postCommand: optPostCmd
        )
    }

    // число активных дополнительных опций (для бейджа на кнопке)
    private var activeOptionCount: Int {
        [optCompress, optProgress, optUpdate, optDelete, optStats, optNoOwner, optMkpath, optSudo]
            .filter { $0 }.count
            + (optBwlimit.trimmingCharacters(in: .whitespaces).isEmpty ? 0 : 1)
            + (optChmod.trimmingCharacters(in: .whitespaces).isEmpty ? 0 : 1)
            + (direction == .upload && !optPostCmd.trimmingCharacters(in: .whitespaces).isEmpty ? 1 : 0)
    }

    private var command: String {
        buildCommand(
            direction: direction, options: options, port: port, excludes: excludes,
            localPath: localPath, userHost: userHost, remotePath: remotePath
        )
    }

    // та же команда, но с -n (dry-run) для Preview
    private var previewCommand: String {
        var o = options
        o.dryRun = true
        return buildCommand(
            direction: direction, options: o, port: port, excludes: excludes,
            localPath: localPath, userHost: userHost, remotePath: remotePath
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            topBar

            HStack(spacing: 8) {
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
                } label: {
                    Image(systemName: "chevron.down")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .accessibilityLabel(s.serverProfiles)
                Button(s.saveButton) { saveCurrentAsProfile() }.help(s.saveHelp)
            }

            HStack(spacing: 8) {
                Text(s.portLabel).foregroundStyle(.secondary)
                TextField("22", text: $port)
                    .frame(width: 70)
                    .focused($focus, equals: .port)
                    .accessibilityLabel(s.portLabel)
                    .onChange(of: port) { _, new in
                        let digits = new.filter(\.isNumber)
                        if digits != new { port = digits }
                    }
                Text(s.passwordLabel).foregroundStyle(.secondary)
                SecureField(s.passwordPlaceholder, text: $password)
                    .focused($focus, equals: .password)
                    .accessibilityLabel(s.passwordLabel)
                    .help(s.passwordHelp)
            }

            // локальная сторона: drop-зона + Обзор
            VStack(alignment: .leading, spacing: 2) {
                Text(localLabel).font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    TextField(s.localPlaceholder, text: $localPath, axis: .vertical)
                        .lineLimit(1...2)
                        .focused($focus, equals: .local)
                        .help(s.localHelp)
                    Button(s.browse) { browse() }.help(s.browseHelp)
                }
                .padding(5)
                .background(dropLocal ? Color.accentColor.opacity(0.15) : .clear)
                .overlay(dropBorder)
                .dropDestination(for: URL.self) { urls, _ in
                    guard let u = urls.first else { return false }
                    localPath = u.path
                    return true
                } isTargeted: {
                    dropLocal = $0
                }
                if localPath.isEmpty {
                    Text(s.localTip).font(.caption2).foregroundStyle(.tertiary)
                }
            }

            // серверная сторона: ввод/вставка
            VStack(alignment: .leading, spacing: 2) {
                Text(remoteLabel).font(.caption).foregroundStyle(.secondary)
                TextField(s.remotePlaceholder, text: $remotePath, axis: .vertical)
                    .lineLimit(1...2)
                    .focused($focus, equals: .remote)
                    .help(s.remoteHelp)
            }

            HStack(spacing: 10) {
                Toggle("-a", isOn: $flagA).accessibilityLabel(s.flagAA11y).help(s.flagAHelp)
                Toggle("-v", isOn: $flagV).accessibilityLabel(s.flagVA11y).help(s.flagVHelp)
                Toggle("-c", isOn: $flagC).accessibilityLabel(s.flagCA11y).help(s.flagCHelp)
                Spacer()
                Button {
                    showOptions.toggle()
                } label: {
                    HStack(spacing: 3) {
                        Text(activeOptionCount > 0 ? "\(s.optionsTitle): \(activeOptionCount)" : s.optionsTitle)
                        Image(systemName: "chevron.down").font(.caption2)
                    }
                }
                .popover(isPresented: $showOptions, arrowEdge: .bottom) { optionsPopover }
                Button {
                    showExcludes.toggle()
                } label: {
                    HStack(spacing: 3) {
                        Text("\(s.excludeSection): \(enabledExcludeCount)")
                        Image(systemName: "chevron.down").font(.caption2)
                    }
                }
                .popover(isPresented: $showExcludes, arrowEdge: .bottom) { excludesPopover }
            }
            .toggleStyle(.checkbox)

            Text(command.isEmpty ? " " : command)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))

            if !isComplete {
                Label(s.incompleteWarning, systemImage: "exclamationmark.triangle")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            if showResult {
                resultBanner
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            if let importNotice {
                Label(importNotice, systemImage: "square.and.arrow.down")
                    .font(.caption).foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
        .padding(12)
        .frame(width: 460)
        .animation(.easeInOut(duration: 0.2), value: showResult)
        .animation(.easeInOut(duration: 0.2), value: importNotice)
        .onAppear {
            NSApp.activate()
            focus = .server
        }
        .task { await maybeAutoCheck() }
    }

    // шапка панели: направление + Copy/Run + меню «•••»
    private var topBar: some View {
        HStack(spacing: 8) {
            Picker("", selection: $direction) {
                Label(s.upload, systemImage: "arrow.up.circle").tag(Direction.upload)
                Label(s.download, systemImage: "arrow.down.circle").tag(Direction.download)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()

            Spacer()

            Button {
                previewOrCancel()
            } label: {
                if isRunning && runner.successMode == .showOutput {
                    ProgressView().controlSize(.small).accessibilityLabel(s.runRunning)
                } else {
                    Image(systemName: "eye")
                }
            }
            .disabled(!isComplete || (isRunning && runner.successMode == .toast))
            .help(s.previewHelp)
            .accessibilityLabel(s.previewLabel)

            Button {
                copy()
            } label: {
                Label(copied ? s.copied : s.copy, systemImage: copied ? "checkmark" : "doc.on.doc")
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .help(s.copyHelp)
            .changeEffect(
                .spray(origin: UnitPoint(x: 0.5, y: 1)) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }, value: copied, isEnabled: copied && !reduceMotion)

            Button {
                runOrCancel()
            } label: {
                if isRunning && runner.successMode == .toast {
                    ProgressView().controlSize(.small).tint(.white).accessibilityLabel(s.runRunning)
                } else {
                    Label(s.run, systemImage: "play.fill")
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(!isComplete || (isRunning && runner.successMode == .showOutput))
            .help(s.runHelp)
            .changeEffect(.shine(duration: 0.7), value: startPulse, isEnabled: !reduceMotion)

            Menu {
                Button(s.runInTerminalItem) { runInTerminal() }.disabled(!isComplete)
                Divider()
                Button(s.importSSHItem) { importFromSSHConfig() }
                Divider()
                updateMenuItems
                Divider()
                Button(s.settingsItem) { openSettings() }
                Button("About rsync builder") { showAboutPanel() }
                Divider()
                Button(s.quitItem) { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    private var excludesPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(s.excludeSection).font(.headline)
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
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
                Button {
                    addExclude()
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(newExclude.trimmingCharacters(in: .whitespaces).isEmpty)
                .help(s.addExcludeHelp)
            }
        }
        .padding(12)
        .frame(width: 300)
    }

    // поповер дополнительных опций rsync; у каждого переключателя своя подсказка (.help)
    private var optionsPopover: some View {
        ScrollView { optionsBody }
            .frame(width: 300, height: 420)
    }

    private var optionsBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(s.safetyHeader).font(.caption).foregroundStyle(.secondary)
            Toggle(s.optDeleteLabel, isOn: $optDelete).help(s.optDeleteHelp)
            if optDelete {
                Text(s.optDeleteWarn).font(.caption2).foregroundStyle(.orange)
            }
            Toggle(s.optUpdateLabel, isOn: $optUpdate).help(s.optUpdateHelp)

            Divider()

            Text(s.transferHeader).font(.caption).foregroundStyle(.secondary)
            Toggle(s.optCompressLabel, isOn: $optCompress).help(s.optCompressHelp)
            Toggle(s.optProgressLabel, isOn: $optProgress).help(s.optProgressHelp)
            Toggle(s.optStatsLabel, isOn: $optStats).help(s.optStatsHelp)
            HStack(spacing: 6) {
                Text(s.optBwlimitLabel)
                TextField("", text: $optBwlimit)
                    .frame(width: 70)
                    .help(s.optBwlimitHelp)
                    .onChange(of: optBwlimit) { _, new in
                        let digits = new.filter(\.isNumber)
                        if digits != new { optBwlimit = digits }
                    }
                Text("KB/s").foregroundStyle(.secondary)
            }
            .help(s.optBwlimitHelp)

            Divider()

            Text(s.deployHeader).font(.caption).foregroundStyle(.secondary)
            Toggle(s.optNoOwnerLabel, isOn: $optNoOwner).help(s.optNoOwnerHelp)
            Toggle(s.optMkpathLabel, isOn: $optMkpath).help(s.optMkpathHelp)
            Toggle(s.optSudoLabel, isOn: $optSudo).help(s.optSudoHelp)
            HStack(spacing: 6) {
                Text(s.optChmodLabel)
                TextField("Du=rwx,go=rx", text: $optChmod).help(s.optChmodHelp)
            }
            if direction == .upload {
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.optPostLabel).font(.caption).foregroundStyle(.secondary)
                    TextField(s.optPostPlaceholder, text: $optPostCmd, axis: .vertical)
                        .lineLimit(1...2)
                        .help(s.optPostHelp)
                }
            } else {
                Text(s.optPostUploadOnly).font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .toggleStyle(.checkbox)
        .padding(12)
    }

    // небольшое уведомление-баннер внутри панели: итог запуска (ошибка или вывод Preview)
    private var resultBanner: some View {
        let failed: Bool
        if case .finished(let code) = runner.state { failed = code != 0 } else { failed = false }
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: failed ? "xmark.octagon.fill" : "checkmark.circle.fill")
                    .foregroundStyle(failed ? .red : .green)
                Text(resultTitle).font(.callout).bold()
                Spacer()
                Button {
                    runner.dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                .accessibilityLabel(s.runClose)
            }
            if !runner.output.isEmpty && (failed || runner.successMode == .showOutput) {
                ScrollView {
                    Text(runner.output)
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 150)
                .padding(6)
                .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder((failed ? Color.red : Color.green).opacity(0.4))
        )
        .accessibilityElement(children: .combine)
    }

    private var resultTitle: String {
        if case .finished(let code) = runner.state {
            return code == 0 ? s.runDone : "\(s.runFailed) (exit \(code))"
        }
        return ""
    }

    // проверка обновлений в меню «•••»: кнопка проверки + статус последнего исхода
    @ViewBuilder private var updateMenuItems: some View {
        if case .checking = updater.state {
            Text(s.updateChecking)
        } else {
            Button(s.checkUpdatesButton) { Task { await updater.check() } }
        }
        switch updater.state {
        case .upToDate:
            Text(s.updateUpToDate)
        case .available(let version, let url):
            Button("\(s.updateAvailable) \(version)") {
                if let u = URL(string: url) { openURL(u) }
            }
        case .failed(let msg):
            Text("\(s.updateFailed) \(msg)")
        case .idle, .checking:
            EmptyView()
        }
    }

    // пунктирная рамка drop-зоны (контрастнее при наведении)
    private var dropBorder: some View {
        RoundedRectangle(cornerRadius: 6)
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
            .foregroundStyle(dropLocal ? Color.accentColor : Color.secondary.opacity(0.7))
    }

    private func runCommand() {
        startPulse += 1
        runner.run(command: command, port: port, password: password, successMode: .toast)
    }

    // Preview: запуск с -n (dry-run), ничего не меняет; вывод и есть цель - показываем его
    private func preview() {
        startPulse += 1
        runner.run(command: previewCommand, port: port, password: password, successMode: .showOutput)
    }

    // Run/Preview на ходу превращаются в отмену, пока идёт их же запуск
    private var isRunning: Bool { runner.state == .running }

    private func runOrCancel() {
        if isRunning { runner.cancel() } else { runCommand() }
    }

    private func previewOrCancel() {
        if isRunning { runner.cancel() } else { preview() }
    }

    // баннер результата показываем на любой финал: успех - короткая галочка, ошибка/Preview - с выводом
    private var showResult: Bool {
        if case .finished = runner.state { return true }
        return false
    }

    // запасной путь: терминал для случаев, которые полем не решить (2FA, подтверждение host key)
    private func runInTerminal() {
        startPulse += 1
        terminal.run(command: command)
    }

    // тихая автопроверка обновления не чаще раза в сутки (по первому открытию панели за день)
    private func maybeAutoCheck() async {
        let now = Date().timeIntervalSince1970
        guard now - lastUpdateCheckAt > 86_400 else { return }
        lastUpdateCheckAt = now
        await updater.checkSilently()
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

    // подгружает серверы из ~/.ssh/config, добавляя только новые (дедуп по userHost)
    private func importFromSSHConfig() {
        let existing = Set(profiles.map(\.userHost))
        let fresh = readSSHConfigProfiles().filter { !existing.contains($0.userHost) }
        profiles.append(contentsOf: fresh)
        importNotice = fresh.isEmpty ? s.importNone : "\(s.importAdded) \(fresh.count)"
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { importNotice = nil }
    }

    // @Default сохраняет автоматически при мутации массива; обновляем существующий профиль
    // только при совпадении и хоста, и пути - иначе добавляем новый, чтобы не затирать чужой путь
    private func saveCurrentAsProfile() {
        let name = userHost.split(separator: "@").first.map(String.init) ?? userHost
        let profile = ServerProfile(name: name, userHost: userHost, port: port, remotePath: remotePath)
        if let idx = profiles.firstIndex(where: { $0.userHost == userHost && $0.remotePath == remotePath }) {
            profiles[idx] = profile
        } else {
            profiles.append(profile)
        }
    }
}

private let menuBarIcon = makeMenuBarIcon()

@main
struct RsyncBuilderApp: App {
    @StateObject private var updater = UpdateChecker()

    var body: some Scene {
        MenuBarExtra {
            ContentView().environmentObject(updater)
        } label: {
            Image(nsImage: menuBarIcon)
        }
        .menuBarExtraStyle(.window)
        .commands { TextEditingCommands() }  // Cmd+C/V/X/A/Z в полях у menu-bar приложения без главного меню

        Settings {
            SettingsView()
        }
    }
}
