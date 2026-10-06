# Quickshell bar

DWM-style status bar for Hyprland: workspaces in Japanese numerals on the left,
active window title centred, system tray and clock on the right.

## How it is deployed

Nix, not by hand. `../../default.nix` copies this whole directory into the store via
`xdg.configFile."quickshell".source` and runs it from the `quickshell.service` user
unit — there is no `cp` step, no `exec-once` line, and `~/.config/quickshell` is a
read-only symlink into the store. Editing a `.qml` here takes effect on the next
rebuild, not on save.

Everything configurable — the unit, the fonts, the icon theme, which scripts the bar
may call — is declared in that same `default.nix`. This file deliberately does not
restate it: an earlier version of this README described an Arch install with
`pacman`, a manual `cp *.qml`, and a day/night schedule that had not matched the code
for months.

## Colours

`shell.qml` holds NO palette of its own. It reads stylix's generated
`~/.config/stylix/palette.json` through a `FileView` (`paletteFile`) into
`root.base16`, and `c(slot, fallback)` maps base16 slots onto the bar's colour
roles. The only hexes written in the QML are per-slot fallbacks
(gruvbox-dark-medium) that render solely when that file is missing or
unparseable — a legible bar beats an invisible one, and they are deliberately
not kept in sync with anything.

Palette switching is a home-manager specialisation, not bar-local logic:
`set-theme dark|sepia` (`../../scripts/set-theme.sh`) activates the matching
generation, which relinks `palette.json` along with every other stylix target,
then appends the mode to `$XDG_RUNTIME_DIR/qs-theme`. The bar's `IpcWatcher`
calls `paletteFile.reload()` on that signal — race-free, because the signal is
published only after activation returned. Mode values are `dark` and `sepia`
(legacy `light` is accepted only from the saved mode file and the pipe, and is
mapped to `sepia`; the CLI takes `dark` or `sepia`); there is no light palette,
both schemes are dark by luminance.

`root.isDark` does NOT colour anything any more. It only drives the 🌙/☀ toggle
glyph in `RightSection.qml` (sepia takes the ☀ side, the "light" slot of the
dark/sepia pair). It is read at startup from `$XDG_STATE_HOME/hypr/theme-mode`
and flipped live by the same `qs-theme` watcher — neither is computed from the
clock, and nothing switches on a schedule.

The palette changes only when asked: the bar's toggle button, or the script by hand.
The one automatic caller is the `theme-sync` service in `../../default.nix`, which
runs `set-theme restore` at login — needed because a `nixos-rebuild switch` lands on
the parent generation and would otherwise silently revert you to dark.

So: to recolour the bar, edit the schemes in `modules/theme/tokens.nix` (stylix
regenerates `palette.json` from them); there is nothing to edit here. For how
the rest of the system consumes them, see `modules/home-manager/stylix.nix`.

## Constraints worth knowing before editing

- `FileView` must keep `preload` on. In quickshell 0.3.0 `reload()` does not perform
  the first read when preload is off, so the view stays empty with nothing in the
  log. `scripts/repo-lint.sh` rule 4 fails the build on it.
- Any `~/.config/hypr/*.sh` this tree calls has to exist under `../../scripts/` and
  be deployed by an `xdg.configFile` entry. `repo-lint.sh` rule 2 checks that too —
  the bar's theme button once called a script that was never deployed and failed
  silently.
- `qmllint` and a `qmldir`-versus-filesystem check run in `nix flake check`.
