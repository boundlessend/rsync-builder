<p align="center">
  <img src="Assets/AppIcon.png" alt="rsync builder app icon" width="128">
</p>

<h1 align="center">rsync builder</h1>

<p align="center">
  <strong>Language:</strong> EN | <a href="README.ru.md">RU</a>
</p>

<p align="center">
  <strong>assemble and run rsync commands from the menu bar</strong>
</p>

<p align="center">
  <a href="https://github.com/boundlessend/rsync-builder/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/boundlessend/rsync-builder/actions/workflows/ci.yml/badge.svg"></a>
  <a href="https://github.com/boundlessend/rsync-builder/actions/workflows/release.yml"><img alt="Release DMG" src="https://github.com/boundlessend/rsync-builder/actions/workflows/release.yml/badge.svg"></a>
  <img alt="macOS" src="https://img.shields.io/badge/macOS-26%2B-111827">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5.9-f05138">
  <img alt="license" src="https://img.shields.io/badge/license-BSD--3--Clause-2563eb">
</p>

`rsync builder` is a small native macOS menu bar app that helps you assemble `rsync`
commands for moving files between your Mac and a server. It lives in the menu bar
(no Dock icon); click its icon to open a compact panel that shows the live command,
copies it to the clipboard, or runs it in a terminal.

## Features

- Lives in the menu bar, opens as a popover panel (no Dock icon, no main window)
- Upload / download direction with source ⇄ destination labels
- Server profiles (`user@host`, port, remote path), saved locally and picked from a menu
- Drag a file or folder onto the local field to fill its full path
- Toggle common flags (`-a`, `-v`, `-c`); `--exclude` patterns in a popover
- Extra options popover: `-z` compress, `-P` progress, `-u` update, `--delete`, `--stats`, `--bwlimit`
- Deploy helpers: `--no-owner --no-group`, `--mkpath`, `--chmod`, sudo on the server, and an
  upload-only post-sync command run over ssh (e.g. `cd ~/app && docker compose up -d`)
- Preview button: a dry run (`-n`) to see what would transfer before doing it
- Every toggle has a tooltip explaining what the flag does
- Live command with shell-safe quoting of paths
- Copy to clipboard, or run in a separate terminal window (SSH password prompts work there)
- Interface language (English / Русский) switchable in Settings
- Check for updates in Settings: compares your version against the latest GitHub release

## Install

Download `rsync-builder.dmg` from the [latest release](https://github.com/boundlessend/rsync-builder/releases/latest),
open it, and drag **rsync builder** into **Applications**. The icon appears in the
menu bar; open **••• → Quit** to quit, **••• → Settings…** for preferences.

It is not signed or notarized, so on first launch right-click the app and choose
**Open**, then confirm. Requires macOS 26 or later.

## Build from source

```sh
./build.sh            # release build -> rsync-builder.app
open rsync-builder.app
```

## Development (hot reload)

```sh
./dev.sh              # debug build with -interposable
```

With [InjectionIII](https://github.com/johnno1962/InjectionIII) running, method-body
edits are hot-swapped at runtime. There is no `Inject` dependency, so SwiftUI views
do not auto-refresh - it is a plain debug build plus `-interposable`.

## Logic check

```sh
swiftc Sources/rsync-builder/Command.swift tests/main.swift -o /tmp/rsync_check && /tmp/rsync_check
```

## Dependencies

- [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) - terminal window for running the command
- [Pow](https://github.com/EmergeTools/Pow) - button animations
- [Defaults](https://github.com/sindresorhus/Defaults) - server profile persistence
- Liquid Glass - native macOS 26, no dependency

Your real servers are never stored in source: the code ships with a single
`example` profile, and profiles you save live only in local `UserDefaults`.

## License

BSD 3-Clause. See [LICENSE](LICENSE).
