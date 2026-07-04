import AppKit
import Foundation
import SwiftUI

enum RunState: Equatable {
    case idle, running
    case finished(Int32)
}

// как показывать успех: toast - маленький самоисчезающий индикатор (обычный Run);
// showOutput - оставить вывод на экране (Preview, где вывод и есть цель)
enum SuccessMode {
    case toast, showOutput
}

// borderless-окну по умолчанию нельзя стать key - тогда кнопки и выделение текста не работают; разрешаем
final class HUDWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

// запуск rsync через Process без терминала: статус - всплывающий индикатор в стиле приложения.
// пароль (если задан) подаётся ssh через SSH_ASKPASS и на диск не пишется - только в окружении дочернего процесса.
// ponytail: не эмулятор терминала; -P прогресс с \r в выводе рисуется грубовато, для живого прогресса есть fallback "в терминале"
final class CommandRunner: NSObject, ObservableObject, NSWindowDelegate {
    @Published private(set) var state: RunState = .idle
    @Published private(set) var output = ""
    private(set) var labels = L10n.en
    private(set) var successMode: SuccessMode = .toast
    private var window: NSWindow?
    private var process: Process?
    private var generation = 0

    func run(command: String, port: String, password: String, labels: L10n, successMode: SuccessMode) {
        // повторный запуск: гасим прошлый процесс, чтобы не наслаивался
        if let old = process, old.isRunning { old.terminate() }
        generation += 1
        let gen = generation
        self.labels = labels
        self.successMode = successMode
        output = ""
        state = .running
        ensureWindow()
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
                guard let self else { return }
                self.state = .finished(finished.terminationStatus)
                if self.process === finished { self.process = nil }
                DispatchQueue.main.async { self.window?.center() }  // после смены размера контента вернуть по центру
                // успех обычного Run: индикатор сам исчезает; при ошибке или Preview остаётся
                if finished.terminationStatus == 0, self.successMode == .toast {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                        if self.generation == gen { self.window?.close() }
                    }
                }
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

    func closePanel() {
        window?.close()
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

    private func ensureWindow() {
        if window != nil { return }
        let host = NSHostingController(rootView: RunStatusView(runner: self))
        let w = HUDWindow(contentViewController: host)
        w.styleMask = [.borderless]  // без рамки - как всплывающий индикатор, а не окно
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = true
        // поповер меню-бара живёт на очень высоком уровне; .screenSaver выше него, иначе индикатор уходит под приложение
        w.level = .screenSaver
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]  // виден на всех Spaces и над fullscreen
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

// всплывающий индикатор: крутилка пока идёт, «Готово» при успехе, панель с ошибкой при провале
struct RunStatusView: View {
    @ObservedObject var runner: CommandRunner

    var body: some View {
        content
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder private var content: some View {
        switch runner.state {
        case .idle, .running:
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text(runner.labels.runRunning).font(.headline)
                Button {
                    runner.closePanel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20).padding(.vertical, 16)
        case .finished(let code) where code == 0 && runner.successMode == .toast:
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title2)
                Text(runner.labels.runDone).font(.headline)
            }
            .padding(.horizontal, 24).padding(.vertical, 18)
        case .finished(let code) where code == 0:
            outputPanel(icon: "checkmark.circle.fill", tint: .green, title: runner.labels.runDone)
        case .finished(let code):
            outputPanel(
                icon: "xmark.octagon.fill", tint: .red, title: "\(runner.labels.runFailed) (exit \(code))")
        }
    }

    // панель с заголовком, выводом команды и кнопкой закрытия (ошибка и Preview)
    private func outputPanel(icon: String, tint: Color, title: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon).foregroundStyle(tint).font(.title2)
                Text(title).font(.headline)
                Spacer()
                Button(runner.labels.runClose) { runner.closePanel() }
            }
            if !runner.output.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(runner.output)
                            .font(.system(.caption2, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .frame(width: 440, height: 220)
                    .padding(8)
                    .background(.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
                    .onChange(of: runner.output) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }
        }
        .padding(16)
    }
}
