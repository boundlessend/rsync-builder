// прогон: swiftc Sources/rsync-builder/Command.swift tests/main.swift -o /tmp/rsync_check && /tmp/rsync_check
import Foundation

let ex = defaultExcludes  // .venv .git .env __pycache__ .DS_Store вкл, logs google.json выкл

// upload, порт 22 -> без -e, направление local -> remote
let up = buildCommand(
    direction: .upload, flagA: true, flagV: true, flagC: true,
    port: "22", excludes: [ExcludeItem(pattern: ".venv", on: true)],
    localPath: "/Users/me/dev/app", userHost: "user@example.com",
    remotePath: "~/app/"
)
assert(up == "rsync -avc --exclude='.venv' /Users/me/dev/app user@example.com:~/app/", up)

// нестандартный порт -> добавляется -e "ssh -p 8022"
let withPort = buildCommand(
    direction: .upload, flagA: true, flagV: true, flagC: false,
    port: "8022", excludes: [ExcludeItem(pattern: ".git", on: true), ExcludeItem(pattern: "logs", on: false)],
    localPath: "/Users/me/dev/app/", userHost: "deploy@server.example",
    remotePath: "~/app/"
)
assert(withPort == "rsync -av -e \"ssh -p 8022\" --exclude='.git' /Users/me/dev/app/ deploy@server.example:~/app/", withPort)

// download -> порядок меняется: remote -> local
let down = buildCommand(
    direction: .download, flagA: true, flagV: true, flagC: true,
    port: "22", excludes: [],
    localPath: "~/Downloads/", userHost: "user@example.com",
    remotePath: "~/app/app/scripts/data/x.json"
)
assert(down == "rsync -avc user@example.com:~/app/app/scripts/data/x.json ~/Downloads/", down)

// выключенные исключения не попадают в команду
_ = ex
print("OK: все проверки пройдены")
