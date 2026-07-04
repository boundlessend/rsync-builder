import AppKit
import Foundation
import SwiftUI

enum RunState: Equatable {
    case idle, running
    case finished(Int32)
}

// запуск rsync через Process без терминала: статус показывается компактной нативной плашкой.
// пароль (если задан) подаётся ssh через SSH_ASKPASS и на диск не пишется - только в окружении дочернего процесса.
// ponytail: не эмулятор терминала; -P прогресс с \r в «Подробностях» рисуется грубовато, для живого прогресса есть fallback "в терминале"
final class CommandRunner: NSObject, ObservableObject, NSWindowDelegate {
    @Published private(set) var state: RunState = .idle
    @Published private(set) var output = ""
    private(set) var labels = L10n.en
    private var window: NSWindow?
    private var process: Process?

    func run(command: String, port: String, password: String, title: String, labels: L10n) {
        // повторный запуск: гасим прошлый процесс, чтобы не наслаивался
        if let old = process, old.isRunning { old.terminate() }
        self.labels = labels
        output = ""
        state = .running
        ensureWindow(title: title)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()  // accessory-приложению нужно именно это, иначе окно уходит за активное приложение
        NSApp.activate(ignoringOtherApps: true)

        let (cmd, rsh) = runTransport(command: command, port: port)
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", cmd]
        proc.environment = runEnvironment(
            base: ProcessInfo.processInfo.environment, password: password,
            rsh: rsh, askpassPath: askpassHelperPath())

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { self?.output += text }
        }
        proc.terminationHandler = { [weak self] finished in
            pipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async {
                self?.state = .finished(finished.terminationStatus)
                if self?.process === finished { self?.process = nil }
            }
        }
        do {
            try proc.run()
            process = proc
        } catch {
            output = error.localizedDescription
            state = .finished(127)
        }
    }

    // хелпер для SSH_ASKPASS: печатает пароль из переменной окружения. Секрета в файле нет, только чтение env
    private func askpassHelperPath() -> String {
        let path = NSTemporaryDirectory() + "rsync-builder-askpass.sh"
        FileManager.default.createFile(
            atPath: path,
            contents: askpassScript.data(using: .utf8),
            attributes: [.posixPermissions: 0o700]
        )
        return path
    }

    private func ensureWindow(title: String) {
        if let w = window {
            w.title = title
            return
        }
        let host = NSHostingController(rootView: RunStatusView(runner: self))
        let w = NSWindow(contentViewController: host)
        w.styleMask = [.titled, .closable, .miniaturizable]
        w.title = title
        w.isReleasedWhenClosed = false
        // поповер меню-бара живёт на очень высоком уровне; .screenSaver выше него, иначе плашка уходит под приложение
        w.level = .screenSaver
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]  // виден на всех Spaces и над fullscreen
        w.delegate = self
        w.center()
        window = w
    }

    // окно закрыли - гасим процесс, чтобы rsync не работал вслепую в фоне
    func windowWillClose(_ notification: Notification) {
        if let p = process, p.isRunning { p.terminate() }
    }
}

// плашка статуса: шапка (крутилка / итог) + сам вывод команды, как в терминале
struct RunStatusView: View {
    @ObservedObject var runner: CommandRunner

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if !runner.output.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(runner.output)
                            .font(.system(.caption2, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .frame(height: 220)
                    .padding(8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                    .onChange(of: runner.output) { _, _ in
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 440, alignment: .leading)
    }

    @ViewBuilder private var header: some View {
        switch runner.state {
        case .idle, .running:
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text(runner.labels.runRunning).font(.headline)
            }
        case .finished(let code):
            HStack(spacing: 10) {
                Image(systemName: code == 0 ? "checkmark.circle.fill" : "xmark.octagon.fill")
                    .foregroundStyle(code == 0 ? .green : .red)
                    .font(.title2)
                Text(code == 0 ? runner.labels.runDone : "\(runner.labels.runFailed) (exit \(code))")
                    .font(.headline)
            }
        }
    }
}
