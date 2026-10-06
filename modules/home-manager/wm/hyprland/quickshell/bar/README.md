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

There is exactly one theme, `dither`, so the palette is read once at startup. No
mode file, no signal and no toggle exist; a `nixos-rebuild switch` relinks
`palette.json`; the generated file's store path is an `X-Restart-Triggers` entry
of `quickshell.service`, so a scheme change restarts the bar to pick it up.

So: to recolour the bar, edit the scheme in `modules/theme/dither.yaml` (stylix
regenerates `palette.json` from it); there is nothing to edit here. For how
the rest of the system consumes them, see `modules/home-manager/stylix.nix`.

## Constraints worth knowing before editing

- `FileView` must keep `preload` on. In quickshell 0.3.0 `reload()` does not perform
  the first read when preload is off, so the view stays empty with nothing in the
  log. `scripts/repo-lint.sh` rule 4 fails the build on it.
- Any `~/.config/hypr/*.sh` this tree calls has to exist under `../../scripts/` and
  be deployed by an `xdg.configFile` entry. `repo-lint.sh` rule 2 checks that too —
  a bar button once called a script that was never deployed and failed silently.
- `qmllint` and a `qmldir`-versus-filesystem check run in `nix flake check`.
