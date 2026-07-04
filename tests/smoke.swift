// смоук-тесты БЕЗ реальных серверов: реальный локальный rsync через тот же путь Process,
// и проверка, что пароль реально доезжает по протоколу SSH_ASKPASS.
// прогон: swiftc Sources/rsync-builder/Command.swift tests/smoke.swift -o /tmp/rsync_smoke && /tmp/rsync_smoke
import Foundation

func sh(_ command: String, env: [String: String]) -> (out: String, code: Int32) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/sh")
    p.arguments = ["-c", command]
    p.environment = env
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = pipe
    try! p.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return (String(data: data, encoding: .utf8) ?? "", p.terminationStatus)
}

@main
struct Smoke {
    static func main() {
        let fm = FileManager.default
        let base = NSTemporaryDirectory() + "rb-smoke-\(getpid())/"
        defer { try? fm.removeItem(atPath: base) }

        // --- Тест 1: реальный локальный rsync через тот же Process + runEnvironment ---
        let src = base + "src/"
        let dst = base + "dst/"
        try! fm.createDirectory(atPath: src, withIntermediateDirectories: true)
        fm.createFile(atPath: src + "a.txt", contents: Data("hi".utf8))
        fm.createFile(atPath: src + "b.txt", contents: Data("yo".utf8))

        let (cmd, rsh) = runTransport(command: "rsync -av \(src) \(dst)", port: "22")
        let env = runEnvironment(base: ProcessInfo.processInfo.environment, rsh: rsh, askpass: "")
        let r1 = sh(cmd, env: env)
        assert(r1.code == 0, "rsync failed: \(r1.out)")
        assert(
            fm.fileExists(atPath: dst + "a.txt") && fm.fileExists(atPath: dst + "b.txt"),
            "files not copied")
        assert(r1.out.contains("a.txt") && r1.out.contains("b.txt"), "verbose output missing: \(r1.out)")
        print("smoke 1 ok: локальный rsync прошёл, файлы скопированы, вывод стримится")

        // --- Тест 2: пароль реально доезжает до потребителя по протоколу SSH_ASKPASS ---
        // пароль лежит в 0600-файле, хелпер его читает; ssh запускает $SSH_ASKPASS и берёт пароль из stdout
        let secret = "p@ss w0rd $ecret!"  // спецсимволы: проверяем, что ничего не ломается по пути
        let pwFile = base + "secret.pw"
        try! secret.write(toFile: pwFile, atomically: true, encoding: .utf8)
        try! fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: pwFile)
        let askpath = base + "askpass.sh"
        try! askpassScript(passwordFile: pwFile).write(toFile: askpath, atomically: true, encoding: .utf8)
        try! fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: askpath)

        let outfile = base + "got.txt"
        var penv = runEnvironment(base: ProcessInfo.processInfo.environment, rsh: "ssh", askpass: askpath)
        penv["OUTFILE"] = outfile
        let r2 = sh("pw=$(\"$SSH_ASKPASS\" \"Password:\"); printf '%s' \"$pw\" > \"$OUTFILE\"", env: penv)
        assert(r2.code == 0, "consumer failed: \(r2.out)")
        let got = (try? String(contentsOfFile: outfile, encoding: .utf8)) ?? ""
        assert(got == secret, "password mismatch: got [\(got)] want [\(secret)]")
        assert(penv["RSYNC_BUILDER_PASS"] == nil, "password must not be in the environment")
        print("smoke 2 ok: пароль доставлен через файл + SSH_ASKPASS, в окружении его нет")

        // --- Тест 3: пустой askpass - проводка не выставляется ---
        let noPassEnv = runEnvironment(base: [:], rsh: "ssh", askpass: "")
        assert(noPassEnv["SSH_ASKPASS"] == nil, "askpass wiring leaked with empty askpass")
        print("smoke 3 ok: без пароля проводка askpass не выставляется")

        print("OK: смоук-тесты пройдены")
    }
}
