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

`shell.qml` holds two hardcoded gruvbox palettes, `darkTheme` and `lightTheme`, and
`theme` picks between them from `root.isDark`. That is a deliberate fourth copy of
the palette (the others are the two Stylix instances and starship): Stylix exposes
only ONE palette per evaluation, and the bar needs both at once so it can flip
without a rebuild.

`isDark` is not computed from the clock. It is read at startup from
`$XDG_STATE_HOME/hypr/theme-mode` and flipped live by an `IpcWatcher` on
`$XDG_RUNTIME_DIR/qs-theme`, both written by `../../scripts/set-theme.sh`
(`set-theme dark|light|toggle|auto`). The schedule lives in the `theme-sync` timer in
`../../default.nix`, at 09:00 and 18:00 — not in this directory.

So: to recolour the bar, edit the two palettes here. To change WHEN it flips, edit
the timer. To change what the rest of the system does, see
`modules/home-manager/stylix.nix`.

## Constraints worth knowing before editing

- `FileView` must keep `preload` on. In quickshell 0.3.0 `reload()` does not perform
  the first read when preload is off, so the view stays empty with nothing in the
  log. `scripts/repo-lint.sh` rule 4 fails the build on it.
- Any `~/.config/hypr/*.sh` this tree calls has to exist under `../../scripts/` and
  be deployed by an `xdg.configFile` entry. `repo-lint.sh` rule 2 checks that too —
  the bar's theme button once called a script that was never deployed and failed
  silently.
- `qmllint` and a `qmldir`-versus-filesystem check run in `nix flake check`.
