// прогон: swiftc Sources/rsync-builder/Command.swift tests/main.swift -o /tmp/rsync_check && /tmp/rsync_check
import Foundation

// базовый набор: -a -v -c, остальное выключено
let avc = RsyncOptions(
    archive: true, verbose: true, checksum: true, compress: false, progress: false,
    update: false, delete: false, stats: false, dryRun: false, bwlimit: "",
    noOwnerGroup: false, mkpath: false, chmod: "", sudo: false, postCommand: ""
)

// upload, порт 22 -> без -e; простые аргументы без кавычек
let up = buildCommand(
    direction: .upload, options: avc, port: "22",
    excludes: [ExcludeItem(pattern: ".venv", on: true)],
    localPath: "/Users/me/dev/project", userHost: "user@example.com", remotePath: "~/app/"
)
assert(up == "rsync -avc --exclude=.venv /Users/me/dev/project user@example.com:~/app/", up)

// нестандартный порт -> -e "ssh -p 8022", без -c
var av = avc
av.checksum = false
let withPort = buildCommand(
    direction: .upload, options: av, port: "8022",
    excludes: [ExcludeItem(pattern: ".git", on: true), ExcludeItem(pattern: "logs", on: false)],
    localPath: "/Users/me/dev/project/", userHost: "deploy@server.example", remotePath: "~/app/"
)
assert(withPort == "rsync -av -e \"ssh -p 8022\" --exclude=.git /Users/me/dev/project/ deploy@server.example:~/app/", withPort)

// download -> порядок меняется
let down = buildCommand(
    direction: .download, options: avc, port: "22", excludes: [],
    localPath: "~/Downloads/", userHost: "user@example.com", remotePath: "/srv/app/data/x.json"
)
assert(down == "rsync -avc user@example.com:/srv/app/data/x.json ~/Downloads/", down)

// путь с пробелом -> закавычивается
let spaced = buildCommand(
    direction: .upload, options: avc, port: "22", excludes: [],
    localPath: "/Users/me/My Project", userHost: "user@example.com", remotePath: "~/x/"
)
assert(spaced == "rsync -avc '/Users/me/My Project' user@example.com:~/x/", spaced)

// инъекция в путь -> обезврежена кавычками
let injected = buildCommand(
    direction: .upload, options: avc, port: "22",
    excludes: [ExcludeItem(pattern: "a b", on: true)],
    localPath: "/tmp/x; rm -rf ~", userHost: "user@example.com", remotePath: "~/x/"
)
assert(injected == "rsync -avc --exclude='a b' '/tmp/x; rm -rf ~' user@example.com:~/x/", injected)

// сжатие + прогресс + update -> кластер флагов
var tuned = avc
tuned.compress = true
tuned.progress = true
tuned.update = true
let t = buildCommand(
    direction: .upload, options: tuned, port: "22", excludes: [],
    localPath: "/Users/me/x", userHost: "user@example.com", remotePath: "~/app/"
)
assert(t == "rsync -avczuP /Users/me/x user@example.com:~/app/", t)

// delete + stats + bwlimit
var deploy = avc
deploy.delete = true
deploy.stats = true
deploy.bwlimit = "1000"
let d = buildCommand(
    direction: .upload, options: deploy, port: "22", excludes: [],
    localPath: "/Users/me/x", userHost: "user@example.com", remotePath: "~/app/"
)
assert(d == "rsync -avch --delete --stats --bwlimit=1000 /Users/me/x user@example.com:~/app/", d)

// dry-run (Preview) -> добавляется n в кластер
var dry = avc
dry.dryRun = true
let p = buildCommand(
    direction: .upload, options: dry, port: "22", excludes: [],
    localPath: "/Users/me/x", userHost: "user@example.com", remotePath: "~/app/"
)
assert(p == "rsync -avcn /Users/me/x user@example.com:~/app/", p)

// деплой-хелперы: sudo + no-owner/group + mkpath + chmod
var helpers = avc
helpers.sudo = true
helpers.noOwnerGroup = true
helpers.mkpath = true
helpers.chmod = "Du=rwx,go=rx"
let h = buildCommand(
    direction: .upload, options: helpers, port: "22", excludes: [],
    localPath: "/Users/me/x", userHost: "user@example.com", remotePath: "~/app/"
)
assert(h == "rsync -avc --rsync-path=\"sudo rsync\" --no-owner --no-group --mkpath --chmod=Du=rwx,go=rx /Users/me/x user@example.com:~/app/", h)

// пост-команда (upload) -> && ssh с портом и кавычками вокруг команды
var post = avc
post.postCommand = "cd ~/app && docker compose up -d"
let pc = buildCommand(
    direction: .upload, options: post, port: "8022", excludes: [],
    localPath: "/Users/me/x", userHost: "deploy@server.example", remotePath: "~/app/"
)
assert(
    pc == "rsync -avc -e \"ssh -p 8022\" /Users/me/x deploy@server.example:~/app/ && ssh -p 8022 deploy@server.example 'cd ~/app && docker compose up -d'", pc)

// пост-команда игнорируется на download
var postDown = avc
postDown.postCommand = "echo hi"
let pd = buildCommand(
    direction: .download, options: postDown, port: "22", excludes: [],
    localPath: "~/x/", userHost: "user@example.com", remotePath: "~/app/"
)
assert(pd == "rsync -avc user@example.com:~/app/ ~/x/", pd)

// сравнение версий: тег с 'v', числовое (не лексическое) сравнение, равенство при разной длине
assert(isUpdateAvailable(current: "1.2", latestTag: "v1.3.0"))
assert(isUpdateAvailable(current: "1.2", latestTag: "v1.2.1"))
assert(isUpdateAvailable(current: "1.9", latestTag: "v1.10.0"))  // 10 > 9 численно, не лексически
assert(!isUpdateAvailable(current: "1.2", latestTag: "v1.2.0"))
assert(!isUpdateAvailable(current: "1.2", latestTag: "v1.2"))
assert(!isUpdateAvailable(current: "1.2.0", latestTag: "v1.1.9"))

print("OK: все проверки пройдены")
