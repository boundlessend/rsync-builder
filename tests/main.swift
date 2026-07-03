// прогон: swiftc Sources/rsync-builder/Command.swift tests/main.swift -o /tmp/rsync_check && /tmp/rsync_check
import Foundation

// upload, порт 22 -> без -e; простые аргументы без кавычек
let up = buildCommand(
    direction: .upload, flagA: true, flagV: true, flagC: true,
    port: "22", excludes: [ExcludeItem(pattern: ".venv", on: true)],
    localPath: "/Users/me/dev/project", userHost: "user@example.com",
    remotePath: "~/app/"
)
assert(up == "rsync -avc --exclude=.venv /Users/me/dev/project user@example.com:~/app/", up)

// нестандартный порт -> добавляется -e "ssh -p 8022"
let withPort = buildCommand(
    direction: .upload, flagA: true, flagV: true, flagC: false,
    port: "8022", excludes: [ExcludeItem(pattern: ".git", on: true), ExcludeItem(pattern: "logs", on: false)],
    localPath: "/Users/me/dev/project/", userHost: "deploy@server.example",
    remotePath: "~/app/"
)
assert(withPort == "rsync -av -e \"ssh -p 8022\" --exclude=.git /Users/me/dev/project/ deploy@server.example:~/app/", withPort)

// download -> порядок меняется: remote -> local
let down = buildCommand(
    direction: .download, flagA: true, flagV: true, flagC: true,
    port: "22", excludes: [],
    localPath: "~/Downloads/", userHost: "user@example.com",
    remotePath: "/srv/app/data/x.json"
)
assert(down == "rsync -avc user@example.com:/srv/app/data/x.json ~/Downloads/", down)

// путь с пробелом -> закавычивается
let spaced = buildCommand(
    direction: .upload, flagA: true, flagV: true, flagC: true,
    port: "22", excludes: [],
    localPath: "/Users/me/My Project", userHost: "user@example.com",
    remotePath: "~/x/"
)
assert(spaced == "rsync -avc '/Users/me/My Project' user@example.com:~/x/", spaced)

// инъекция в путь -> обезврежена кавычками, а не выполняется
let injected = buildCommand(
    direction: .upload, flagA: true, flagV: true, flagC: true,
    port: "22", excludes: [ExcludeItem(pattern: "a b", on: true)],
    localPath: "/tmp/x; rm -rf ~", userHost: "user@example.com",
    remotePath: "~/x/"
)
assert(injected == "rsync -avc --exclude='a b' '/tmp/x; rm -rf ~' user@example.com:~/x/", injected)

print("OK: все проверки пройдены")
