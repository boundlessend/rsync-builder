# rsync builder - PRD

Status: v1.3 shipped (Phases 1-2 of the expansion done, plus terminal-free run + password auth).
This document records the current state and the planned expansion so nothing gets lost.

Last updated: 2026-07-19

## 1. Purpose

A macOS menu bar app that helps assemble and run `rsync` commands for moving files
between a Mac and a server. Target user: a developer who repeatedly pushes project
folders to servers and wants the correct command without memorising flags.

Non-goals: multi-source lists (decided against), code signing/notarization,
being a general file manager.

## 2. Current state (shipped, v1.3.1)

### UX
- Menu bar only app (`MenuBarExtra`, `.window` style, `LSUIElement`): no Dock icon,
  no main window. Monochrome template icon in the status bar; click opens a compact
  popover (~460 pt wide).
- Direction: upload / download, with dynamic source ⇄ destination labels.
- Server field (`user@host`) + profiles menu with a delete submenu; port on its own row.
- Local path: drag-drop a file/folder or Browse; remote path field.
- Flags `-a` `-v` `-c` as checkboxes; non-default SSH port becomes `-e "ssh -p N"`.
- `--exclude` patterns: checkbox grid + custom add and per-row remove, folded into an "Exclude: N ▾" popover.
- Extra options in an "Options ▾" popover (`-z` `-P` `-u` `--delete` `--stats` `--bwlimit`),
  each toggle with a tooltip; a Preview button runs the command with `--dry-run`. (v1.1)
- Deploy helpers in the same popover (`--no-owner --no-group`, `--mkpath`, `--chmod`,
  `--rsync-path="sudo rsync"`) and an upload-only post-sync command appended as
  `rsync … && ssh -p N user@host '<cmd>'`. (v1.2)
- Live command with shell-safe quoting of every path (`shellQuote`).
- Optional SSH password field (`SecureField`, never persisted). Run/Preview execute inline
  via `Process` (`/bin/sh -c`) with no terminal; the password is fed to ssh through an
  `SSH_ASKPASS` helper reading it from a 0600 temp file that exists only for the duration
  of the run (never in the process environment, where `ps eww` would expose it). Empty
  password = key-based login. Host key auto-accepted via
  `RSYNC_RSH=ssh -o StrictHostKeyChecking=accept-new`. (v1.3)
- Run state shown inline: a spinner in the Run/Preview button (doubling as cancel), a brief
  green success check for Run, or an in-panel error banner with the exit code + output.
  Preview surfaces its dry-run output in that banner. (v1.3)
- Copy to clipboard; a "Run in terminal" fallback (SwiftTerm) stays in the "•••" menu for
  2FA / host-key confirmation. (v1.3)
- Buttons in a top bar (direction + Preview + Copy + Run + "•••" menu).
- Localization EN / RU, defaults to the system locale; a System / English / Русский
  switch in the Settings window.
- "Check for updates" in the "•••" menu: queries the GitHub Releases API (native `URLSession`,
  no new dependency) and compares `tag_name` against the app version. A silent auto-check
  runs at most once a day and surfaces only when an update is available. (v1.3: moved from Settings)
- Native Liquid Glass, Pow button effects (gated by Reduce Motion), accessibility
  labels, `@FocusState`, incomplete-command guard (Run disabled until server + both paths).
- Form state persisted between launches (`@AppStorage`); server profiles and exclude
  list persisted via Defaults; real servers live only in local `UserDefaults`, never in source.

### Architecture
- `Command.swift`: pure `buildCommand(...)`, `shellQuote`, `runTransport`, `runEnvironment`,
  `askpassScript`, `ServerProfile`, `ExcludeItem`, `Direction`, defaults.
- `Runner.swift`: `CommandRunner` (runs rsync via `Process`, publishes state/output; no window).
- `App.swift`: `ContentView` (the popover, spinner-in-button + result banner) + `RsyncBuilderApp` scene.
- `Terminal.swift`: `TerminalWindow` (SwiftTerm fallback run window).
- `Persistence.swift`: Defaults keys for profiles/excludes.
- `Localization.swift`, `Settings.swift`, `Menu.swift`, `Update.swift`.
- Deps: SwiftTerm, Pow, Defaults. Requires macOS 26+.
- Tests: assert-based logic (`tests/main.swift`) + server-free smoke (`tests/smoke.swift`:
  local rsync run + `SSH_ASKPASS` password delivery).
- CI: `ci` (build + logic + smoke), `lint` (swift-format, non-blocking), `release`
  (DMG on tag `v*`), `dependency-review`. Public repo, BSD-3. The app version comes
  from the latest git tag (`build.sh` derives it via `git describe`).

## 3. Planned expansion

### 3.1 UI containment strategy
Keep the popover compact. All new controls land in:
- a **Preview** button (split with Run) - runs the built command with `--dry-run`;
- an **"Options ▾" popover** (like Exclude) grouping Safety / Transfer / Deploy toggles and fields;
- one optional **Post-sync command** field;
- **per-profile** persistence so a profile restores its full setup;
- optional **history** entry point in the "•••" menu.

### 3.2 Area A - Safety (shipped in v1.1)
| Feature | UI | Effect on command |
| --- | --- | --- |
| `--dry-run` / `-n` | **Preview** button (and toggle in Options) | prepend `-n`; run in terminal for a no-op check |
| `--delete` | Options toggle, red warning "run Preview first" | add `--delete` (mirror; removes dest files missing from source) |
| `--update` / `-u` | Options toggle | add `-u` (skip files newer on dest) |

### 3.3 Area B - Transfer tuning (shipped in v1.1)
| Feature | UI | Effect |
| --- | --- | --- |
| `-z` / `--compress` | toggle (Options or main flags row) | add `-z` |
| `-P` (`--partial --progress`) | toggle | add `-P` (progress + resume partials) |
| `--bwlimit=RATE` | numeric field | add `--bwlimit=RATE` when set |
| `--stats` / `-h` | toggle | add `--stats -h` |

### 3.4 Area C - Deploy helpers (shipped in v1.2)
| Feature | UI | Effect |
| --- | --- | --- |
| don't preserve ownership | toggle | add `--no-owner --no-group` |
| `--mkpath` | toggle | create missing dest dirs |
| `--chmod=SPEC` | field | add `--chmod=SPEC` |
| sudo on server | toggle | add `--rsync-path="sudo rsync"` |
| **post-sync command** | text field (upload only) | wrap as `rsync … && ssh -p N user@host '<cmd>'` (e.g. `cd ~/app && docker compose up -d`) |

### 3.5 Area D - Bigger features (priority: medium/low)
- **Per-profile settings:** grow `ServerProfile` to store `remotePath`, flags, excludes,
  options, and post-sync command. Selecting a profile restores the whole layout, not
  just `user@host`. Needs a migration for existing profiles + a wider `buildCommand`
  input (an `Options` struct instead of loose booleans).
- **Command history:** persist the last N built/run commands; re-run from the "•••" menu
  or a small clock button.
- **Exclude presets:** named sets (python / node / …) to toggle in one click.
- **Decompose `-a`:** optional advanced toggles for `-r -l -p -t -g -o -D`.

## 4. Data model changes (when Area D lands)
- `ServerProfile` += `flags`, `excludes`, `options`, `postCommand`.
- New `RsyncOptions` struct (dryRun, delete, update, compress, progress, bwlimit,
  stats, noOwnerGroup, mkpath, chmod, sudo) passed into `buildCommand`.
- New Defaults key for history (`[String]`, capped).

## 5. Suggested build order
1. ~~Preview button + Options popover with Area A + B toggles (`-n -z -P -u --delete --bwlimit --stats`).~~ **Done in v1.1.**
2. ~~Area C deploy helpers + post-sync command.~~ **Done in v1.2.**
3. Per-profile settings (model refactor + migration).
4. History, exclude presets, `-a` decomposition.

## 6. Constraints
- Popover stays compact; overflow goes to the Options popover / per-profile.
- No real infrastructure in source (privacy).
- macOS 26+, unsigned build (Gatekeeper right-click-open on first launch).
- Every non-trivial change keeps the `buildCommand` assert test green.

## 7. Open questions
- Inline `-z`/`-P` in the main flags row, or keep them in the Options popover?
- History size cap and whether to store per-profile.
- Per-profile migration: seed new fields from current global state on first run?
