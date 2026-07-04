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

    // при успехе - строка rsync "sent ... received ..."; при ошибке - последняя непустая строка (обычно текст ошибки)
    var summaryLine: String? {
        let lines = output.split(separator: "\n").map(String.init)
        if case .finished(let code) = state, code == 0 {
            return lines.last(where: { $0.hasPrefix("sent ") && $0.contains("received") })
        }
        return lines.last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
    }

    func run(command: String, port: String, password: String, title: String, labels: L10n) {
        // повторный запуск: гасим прошлый процесс, чтобы не наслаивался
        if let old = process, old.isRunning { old.terminate() }
        self.labels = labels
        output = ""
        state = .running
        ensureWindow(title: title)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        let (cmd, rsh) = runTransport(command: command, port: port)
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", cmd]

        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        env["RSYNC_RSH"] = rsh
        if !password.isEmpty {
            env["SSH_ASKPASS"] = askpassHelperPath()
            env["SSH_ASKPASS_REQUIRE"] = "force"
            env["DISPLAY"] = env["DISPLAY"] ?? ":0"
            env["RSYNC_BUILDER_PASS"] = password
        }
        proc.environment = env

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
        let script = "#!/bin/sh\nprintf '%s\\n' \"$RSYNC_BUILDER_PASS\"\n"
        FileManager.default.createFile(
            atPath: path,
            contents: script.data(using: .utf8),
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
        w.delegate = self
        w.center()
        window = w
    }

    // окно закрыли - гасим процесс, чтобы rsync не работал вслепую в фоне
    func windowWillClose(_ notification: Notification) {
        if let p = process, p.isRunning { p.terminate() }
    }
}

// компактная плашка статуса: крутилка пока идёт, затем итог + раскрывашка с полным логом
struct RunStatusView: View {
    @ObservedObject var runner: CommandRunner
    @State private var showDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                        .font(.title)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(code == 0 ? runner.labels.runDone : "\(runner.labels.runFailed) (exit \(code))")
                            .font(.headline)
                        if let sub = runner.summaryLine {
                            Text(sub)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .lineLimit(3)
                        }
                    }
                }
            }

            if !runner.output.isEmpty {
                DisclosureGroup(runner.labels.runDetails, isExpanded: $showDetails) {
                    ScrollView {
                        Text(runner.output)
                            .font(.system(.caption2, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 180)
                }
                .font(.caption)
            }
        }
        .padding(16)
        .frame(width: 380, alignment: .leading)
    }
}
