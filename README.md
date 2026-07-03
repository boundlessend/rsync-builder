# rsync builder

A small native macOS app (SwiftUI) that helps you assemble `rsync` commands for
moving files between your Mac and a server. It shows the live command, copies it
to the clipboard, and can run it in an embedded terminal window.

## Features

- Upload / download direction with source ⇄ destination labels
- Server profiles (`user@host`, port, remote path), saved locally
- Drag a file or folder onto the local field to fill its full path
- Toggle common flags (`-a`, `-v`, `-c`) and `--exclude` patterns
- Live command with shell-safe quoting of paths
- Copy to clipboard, or run in a separate embedded terminal (SSH password prompts work there)

## Build & run

```sh
./build.sh            # release build -> rsync-builder.app
open rsync-builder.app
```

Requires macOS 26+ (uses native Liquid Glass). No code signing; on first run allow it via Gatekeeper.

## Development (hot reload)

```sh
./dev.sh              # debug build with -interposable
```

Needs [InjectionIII](https://github.com/johnno1962/InjectionIII) running to apply
SwiftUI edits live.

## Logic check

```sh
swiftc Sources/rsync-builder/Command.swift tests/main.swift -o /tmp/rsync_check && /tmp/rsync_check
```

## Dependencies

- [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) - embedded terminal window
- [Pow](https://github.com/EmergeTools/Pow) - button animations
- [Defaults](https://github.com/sindresorhus/Defaults) - server profile persistence
- [Inject](https://github.com/krzysztofzablocki/Inject) - SwiftUI hot reload
- Liquid Glass - native macOS 26, no dependency

Your real servers are never stored in source: source ships with an `example`
profile, and profiles you save live only in local `UserDefaults`.

## License

BSD 3-Clause. See [LICENSE](LICENSE).
