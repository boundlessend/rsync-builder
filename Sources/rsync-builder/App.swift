import SwiftUI
import AppKit
import Pow
import Defaults
import Inject

struct ContentView: View {
    @Default(.profiles) private var profiles
    @ObserveInjection private var inject

    @State private var direction: Direction = .upload
    @State private var userHost = "user@example.com"
    @State private var port = "22"
    @State private var localPath = "/Users/me/dev/"
    @State private var remotePath = "~/app/"
    @State private var flagA = true
    @State private var flagV = true
    @State private var flagC = true
    @State private var excludes: [ExcludeItem] = defaultExcludes
    @State private var newExclude = ""
    @State private var copied = false
    @State private var dropLocal = false
    @State private var dropRemote = false
    @StateObject private var terminal = TerminalWindow()
    @State private var startPulse = 0

    // подписи сторон зависят от направления
    private var localLabel: String { direction == .upload ? "Источник · локально" : "Приём · локально" }
    private var remoteLabel: String { direction == .upload ? "Приём · на сервере" : "Источник · на сервере" }

    private var command: String {
        buildCommand(
            direction: direction, flagA: flagA, flagV: flagV, flagC: flagC,
            port: port, excludes: excludes, localPath: localPath,
            userHost: userHost, remotePath: remotePath
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("", selection: $direction) {
                ForEach(Direction.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            // сервер: редактируемое поле + меню профилей + сохранить
            HStack(spacing: 6) {
                Text("Сервер").frame(width: 70, alignment: .leading)
                TextField("user@host", text: $userHost).textFieldStyle(.roundedBorder)
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
                Button("Сохранить") { saveCurrentAsProfile() }
            }

            HStack(spacing: 6) {
                Text("Порт SSH").frame(width: 70, alignment: .leading)
                TextField("22", text: $port).textFieldStyle(.roundedBorder).frame(width: 80)
            }

            // локальная сторона: широкая drop-зона + вставка + Обзор
            VStack(alignment: .leading, spacing: 4) {
                Text(localLabel).font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    TextField("перетащи файл сюда или вставь путь", text: $localPath, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...3)
                    Button("Обзор") { browse() }
                }
                .padding(6)
                .background(dropLocal ? Color.accentColor.opacity(0.15) : .clear)
                .overlay(dropBorder)
                .dropDestination(for: URL.self) { urls, _ in
                    guard let u = urls.first else { return false }
                    localPath = u.path
                    return true
                } isTargeted: { dropLocal = $0 }
            }

            // серверная сторона: широкая зона + вставка (обычно user@host:путь)
            VStack(alignment: .leading, spacing: 4) {
                Text(remoteLabel).font(.subheadline).foregroundStyle(.secondary)
                TextField("путь на сервере (или перетащи файл)", text: $remotePath, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                    .padding(6)
                    .background(dropRemote ? Color.accentColor.opacity(0.15) : .clear)
                    .overlay(dropBorder)
                    .dropDestination(for: URL.self) { urls, _ in
                        guard let u = urls.first else { return false }
                        remotePath = u.path
                        return true
                    } isTargeted: { dropRemote = $0 }
            }

            HStack(spacing: 16) {
                Text("Флаги").frame(width: 70, alignment: .leading)
                Toggle("-a", isOn: $flagA)
                    .help("архивный режим: рекурсивно, сохраняет права, время и симлинки")
                Toggle("-v", isOn: $flagV)
                    .help("подробный вывод - показывать каждый передаваемый файл")
                Toggle("-c", isOn: $flagC)
                    .help("сверять файлы по контрольной сумме, а не по размеру и времени (медленнее, надёжнее)")
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Исключить").font(.subheadline).foregroundStyle(.secondary)
                excludeGrid
                HStack(spacing: 6) {
                    TextField("своё исключение", text: $newExclude).textFieldStyle(.roundedBorder)
                    Button("＋ добавить") { addExclude() }
                        .disabled(newExclude.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Divider()

            // область команды тянется по вертикали и забирает лишнее место при ресайзе
            Text(command)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(10)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(6)

            HStack {
                Spacer()
                Button(copied ? "Скопировано ✓" : "Копировать") { copy() }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                    .buttonStyle(.glass)
                    .changeEffect(.spray(origin: UnitPoint(x: 0.5, y: 0)) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }, value: copied, isEnabled: copied)
                Button("▶ Старт") {
                    startPulse += 1
                    terminal.run(command: command)
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.glassProminent)
                .changeEffect(.shine(duration: 0.7), value: startPulse)
            }
        }
        .padding(18)
        .frame(minWidth: 520, idealWidth: 620, maxWidth: .infinity,
               minHeight: 440, idealHeight: 520, maxHeight: .infinity,
               alignment: .top)
        .onAppear {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
        .enableInjection()
    }

    // пунктирная рамка drop-зоны
    private var dropBorder: some View {
        RoundedRectangle(cornerRadius: 6)
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
            .foregroundStyle(.secondary.opacity(0.4))
    }

    private var excludeGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
            ForEach($excludes) { $ex in
                Toggle(ex.pattern, isOn: $ex.on).lineLimit(1)
            }
        }
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
    var body: some Scene {
        WindowGroup("rsync builder") {
            ContentView()
        }
        .windowResizability(.contentMinSize)
    }
}
