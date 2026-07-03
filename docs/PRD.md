# rsync builder - PRD

Status: v1.0.0 shipped. This document records the current state and the planned
expansion so nothing gets lost.

Last updated: 2026-07-04

## 1. Purpose

A macOS menu bar app that helps assemble and run `rsync` commands for moving files
between a Mac and a server. Target user: a developer who repeatedly pushes project
folders to servers and wants the correct command without memorising flags.

Non-goals: multi-source lists (decided against), code signing/notarization,
being a general file manager.

## 2. Current state (shipped, v1.0.0)

### UX
- Menu bar only app (`MenuBarExtra`, `.window` style, `LSUIElement`): no Dock icon,
  no main window. Monochrome template icon in the status bar; click opens a compact
  popover (~460 pt wide).
- Direction: upload / download, with dynamic source ⇄ destination labels.
- Server field (`user@host`) + profiles menu; port on its own row.
- Local path: drag-drop a file/folder or Browse; remote path field.
- Flags `-a` `-v` `-c` as checkboxes; non-default SSH port becomes `-e "ssh -p N"`.
- `--exclude` patterns: checkbox grid + custom add, folded into an "Exclude: N ▾" popover.
- Live command with shell-safe quoting of every path (`shellQuote`).
- Copy to clipboard; Run in a separate terminal window (SwiftTerm), where SSH
  password/passphrase prompts work.
- Buttons in a top bar (direction + Copy + Run + "•••" menu with Settings / About / Quit).
- Localization EN / RU, language switch in the Settings window (default EN).
- Native Liquid Glass, Pow button effects (gated by Reduce Motion), accessibility
  labels, `@FocusState`, incomplete-command guard (Run disabled until server + both paths).
- Form state persisted between launches (`@AppStorage`); server profiles persisted
  via Defaults; real servers live only in local `UserDefaults`, never in source.

### Architecture
- `Command.swift`: pure `buildCommand(...)`, `shellQuote`, `ServerProfile`, `ExcludeItem`,
  `Direction`, `defaultProfiles` (single `example` profile), `defaultExcludes`.
- `App.swift`: `ContentView` (the popover) + `RsyncBuilderApp` scene (`MenuBarExtra` + `Settings`).
- `Terminal.swift`: `TerminalWindow` (SwiftTerm run window).
- `Persistence.swift`: Defaults key for profiles.
- `Localization.swift`, `Settings.swift`, `Menu.swift`.
- Deps: SwiftTerm, Pow, Defaults, Inject. Requires macOS 26+.
- Tests: assert-based logic check for `buildCommand` (`tests/main.swift`).
- CI: `ci` (build + logic test), `lint` (swift-format, non-blocking), `release`
  (DMG on tag `v*`), `stale`, `dependency-review`. Public repo, BSD-3.

## 3. Planned expansion

### 3.1 UI containment strategy
Keep the popover compact. All new controls land in:
- a **Preview** button (split with Run) - runs the built command with `--dry-run`;
- an **"Options ▾" popover** (like Exclude) grouping Safety / Transfer / Deploy toggles and fields;
- one optional **Post-sync command** field;
- **per-profile** persistence so a profile restores its full setup;
- optional **history** entry point in the "•••" menu.

### 3.2 Area A - Safety (priority: high, low risk)
| Feature | UI | Effect on command |
| --- | --- | --- |
| `--dry-run` / `-n` | **Preview** button (and toggle in Options) | prepend `-n`; run in terminal for a no-op check |
| `--delete` | Options toggle, red warning "run Preview first" | add `--delete` (mirror; removes dest files missing from source) |
| `--update` / `-u` | Options toggle | add `-u` (skip files newer on dest) |

### 3.3 Area B - Transfer tuning (priority: high)
| Feature | UI | Effect |
| --- | --- | --- |
| `-z` / `--compress` | toggle (Options or main flags row) | add `-z` |
| `-P` (`--partial --progress`) | toggle | add `-P` (progress + resume partials) |
| `--bwlimit=RATE` | numeric field | add `--bwlimit=RATE` when set |
| `--stats` / `-h` | toggle | add `--stats -h` |

### 3.4 Area C - Deploy helpers (priority: medium, high fit)
| Feature | UI | Effect |
| --- | --- | --- |
| don't preserve ownership | toggle | add `--no-owner --no-group` |
| `--mkpath` | toggle | create missing dest dirs |
| `--chmod=SPEC` | field | add `--chmod=SPEC` |
| sudo on server | toggle | add `--rsync-path="sudo rsync"` |
| **post-sync command** | text field | wrap as `rsync … && ssh -p N user@host '<cmd>'` (e.g. `cd ~/app && docker compose up -d`) |

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
1. Preview button + Options popover with Area A + B toggles (`-n -z -P -u --delete --bwlimit --stats`). Highest value, self-contained.
2. Area C deploy helpers + post-sync command.
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
