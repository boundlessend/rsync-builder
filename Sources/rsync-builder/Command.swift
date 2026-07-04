import Foundation

// профиль сервера: user@host + порт + путь по умолчанию
struct ServerProfile: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var userHost: String
    var port: String
    var remotePath: String
}

// один пункт исключений (--exclude); Codable - чтобы сохраняться между запусками через Defaults
struct ExcludeItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var pattern: String
    var on: Bool
}

enum Direction: String, CaseIterable {
    case upload = "Upload"
    case download = "Download"
}

// пример профиля; реальные серверы пользователь добавляет сам (хранятся локально в UserDefaults)
let defaultProfiles: [ServerProfile] = [
    ServerProfile(name: "example", userHost: "user@example.com", port: "22", remotePath: "~/remote/")
]

let defaultExcludes: [ExcludeItem] = [
    ExcludeItem(pattern: ".venv", on: true),
    ExcludeItem(pattern: ".git", on: true),
    ExcludeItem(pattern: ".env", on: true),
    ExcludeItem(pattern: "__pycache__", on: true),
    ExcludeItem(pattern: ".DS_Store", on: true),
    ExcludeItem(pattern: "logs", on: false),
    ExcludeItem(pattern: "google.json", on: false),
]

// экранирование аргумента для shell: кавычим только при наличии небезопасных символов
func shellQuote(_ arg: String) -> String {
    let safe = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_./:@%+=~-")
    if arg.unicodeScalars.allSatisfy({ safe.contains($0) }) {
        return arg
    }
    return "'" + arg.replacingOccurrences(of: "'", with: "'\\''") + "'"
}

// набор опций rsync (чекбоксы и поля интерфейса)
struct RsyncOptions {
    var archive: Bool  // -a
    var verbose: Bool  // -v
    var checksum: Bool  // -c
    var compress: Bool  // -z
    var progress: Bool  // -P
    var update: Bool  // -u
    var delete: Bool  // --delete
    var stats: Bool  // --stats + -h
    var dryRun: Bool  // -n (для Preview)
    var bwlimit: String  // --bwlimit=RATE (КБ/с), пусто = без лимита
    var noOwnerGroup: Bool  // --no-owner --no-group
    var mkpath: Bool  // --mkpath (создать недостающие папки назначения)
    var chmod: String  // --chmod=SPEC, пусто = не добавлять
    var sudo: Bool  // --rsync-path="sudo rsync"
    var postCommand: String  // && ssh ... '<cmd>' на сервере после отправки (только upload)
}

// чистая функция сборки команды rsync
func buildCommand(
    direction: Direction,
    options: RsyncOptions,
    port: String,
    excludes: [ExcludeItem],
    localPath: String,
    userHost: String,
    remotePath: String
) -> String {
    // короткие флаги одним кластером
    var short = ""
    if options.archive { short += "a" }
    if options.verbose { short += "v" }
    if options.checksum { short += "c" }
    if options.compress { short += "z" }
    if options.update { short += "u" }
    if options.progress { short += "P" }
    if options.dryRun { short += "n" }
    if options.stats { short += "h" }

    var parts: [String] = ["rsync"]
    if !short.isEmpty { parts.append("-" + short) }
    if options.delete { parts.append("--delete") }
    if options.stats { parts.append("--stats") }

    let rate = options.bwlimit.trimmingCharacters(in: .whitespaces)
    if !rate.isEmpty { parts.append("--bwlimit=\(rate)") }

    if options.sudo { parts.append("--rsync-path=\"sudo rsync\"") }
    if options.noOwnerGroup { parts.append("--no-owner --no-group") }
    if options.mkpath { parts.append("--mkpath") }
    let chmod = options.chmod.trimmingCharacters(in: .whitespaces)
    if !chmod.isEmpty { parts.append("--chmod=\(shellQuote(chmod))") }

    let trimmedPort = port.trimmingCharacters(in: .whitespaces)
    if !trimmedPort.isEmpty, trimmedPort != "22" {
        parts.append("-e \"ssh -p \(trimmedPort)\"")
    }

    for ex in excludes where ex.on && !ex.pattern.trimmingCharacters(in: .whitespaces).isEmpty {
        parts.append("--exclude=" + shellQuote(ex.pattern))
    }

    let local = shellQuote(localPath)
    let remote = shellQuote("\(userHost):\(remotePath)")
    switch direction {
    case .upload:
        parts.append(local)
        parts.append(remote)
    case .download:
        parts.append(remote)
        parts.append(local)
    }
    var result = parts.filter { !$0.isEmpty }.joined(separator: " ")

    // пост-команда: выполнить по ssh на сервере после успешной отправки (только upload)
    let post = options.postCommand.trimmingCharacters(in: .whitespaces)
    if direction == .upload, !post.isEmpty {
        var ssh = "ssh"
        if !trimmedPort.isEmpty, trimmedPort != "22" { ssh += " -p \(trimmedPort)" }
        ssh += " \(shellQuote(userHost)) \(shellQuote(post))"
        result += " && \(ssh)"
    }
    return result
}

// подготовка команды к запуску через Process (без TTY): порт и авто-приём нового host key
// переносятся в RSYNC_RSH, дублирующий -e убирается, чтобы транспорт был единым для 22 и нестандартного порта
func runTransport(command: String, port: String) -> (command: String, rsh: String) {
    let p = port.trimmingCharacters(in: .whitespaces)
    // NumberOfPasswordPrompts=1 - не долбить сервер одним и тем же паролем трижды при ошибке
    var rsh = "ssh -o StrictHostKeyChecking=accept-new -o NumberOfPasswordPrompts=1"
    if !p.isEmpty, p != "22" {
        rsh += " -p \(p)"
        return (command.replacingOccurrences(of: "-e \"ssh -p \(p)\" ", with: ""), rsh)
    }
    return (command, rsh)
}

// содержимое хелпера SSH_ASKPASS: печатает пароль из переменной окружения (секрета в самом файле нет)
let askpassScript = "#!/bin/sh\nprintf '%s\\n' \"$RSYNC_BUILDER_PASS\"\n"

// окружение для запуска rsync через Process: PATH + транспорт, а при заданном пароле - проводка SSH_ASKPASS.
// чистая функция: base не мутируется, возвращается новый словарь
func runEnvironment(base: [String: String], password: String, rsh: String, askpassPath: String) -> [String: String] {
    var env = base
    env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    env["RSYNC_RSH"] = rsh
    if !password.isEmpty {
        env["SSH_ASKPASS"] = askpassPath
        env["SSH_ASKPASS_REQUIRE"] = "force"
        env["DISPLAY"] = env["DISPLAY"] ?? ":0"
        env["RSYNC_BUILDER_PASS"] = password
    }
    return env
}

// сравнение версий: true если latestTag строго новее current (числовое по компонентам, не лексическое)
func isUpdateAvailable(current: String, latestTag: String) -> Bool {
    func parts(_ v: String) -> [Int] {
        let trimmed = v.hasPrefix("v") || v.hasPrefix("V") ? String(v.dropFirst()) : v
        return trimmed.split(separator: ".").map { Int($0) ?? 0 }
    }
    let latest = parts(latestTag)
    let cur = parts(current)
    for i in 0..<max(latest.count, cur.count) {
        let x = i < latest.count ? latest[i] : 0
        let y = i < cur.count ? cur[i] : 0
        if x != y { return x > y }
    }
    return false
}
