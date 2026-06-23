# Hyprland port (cachy → nixos, declarative) — Design

**Date:** 2026-06-23
**Status:** Approved, implementing

## Goal

Port the existing Hyprland setup from `github.com/zapatagustin/cachy-config`
into this NixOS flake, as declaratively as the config allows. Packages pinned by
nix, config as nix attrs where possible, scripts/QML deployed reproducibly.

## Decisions (from brainstorm)

- **hyprland.conf → nix attrs** (`wayland.windowManager.hyprland.settings`).
- **Qt theming via Stylix** (fixed gruvbox-dark); drop the kde/breeze env vars.
- **File manager: yazi** (TUI) instead of dolphin (no KDE).
- **Theme switcher removed** — `set-theme.sh`/`theme-watcher.sh` conflict with
  Stylix (read-only GTK files). Stylix owns GTK/Qt/cursor, fixed dark. A one-shot
  `exec-once` writes `dark` to `/tmp/qs-theme` so Quickshell shows dark.
- **Session: greetd + tuigreet** → `uwsm start hyprland` (cachy had no login mgr).
- **Wallpapers: the 4 used images committed to `wallpapers/`** in this repo
  (~1.7MB), referenced by relative nix path. The full gitlab repo is 687MB; a
  `flake = false` input clones all of it (no sparse-checkout for inputs), so for
  4 images it's not worth it. Move to a small dedicated input if the set grows.

## Discovered constraints

- **Scripts source each other** (`$(dirname $0)/monitors-detect.sh`) and are
  called by path from binds (`~/.config/hypr/switch-monitor.sh`). So they CANNOT
  become `writeShellApplication` (separate store paths break sibling sourcing).
  → Deploy them as files under `~/.config/hypr/` via `xdg.configFile`, with all
  CLI deps (`hyprctl jq grim slurp socat ...`) on the session PATH (home.packages).
  HM-generated `hyprland.conf` and the `*.sh` files coexist in `~/.config/hypr/`.
- **Wallpaper paths in scripts** point at `~/Pictures/Wallpapers/`. Replace with a
  `WALLPAPER_DIR` env var (set to the store path of the wallpapers input) so the
  committed script stays generic + declarative.
- **`coding-2.png`** (hyprlock bg) no longer exists in the wallpapers repo →
  use `3.png` (user choice).
- **Wallpapers repo is large** (~200 imgs). `flake = false` pulls the whole repo
  into the store. Cached; acceptable. Shrink to a dedicated repo later if needed.

## Structure

```
flake.nix                                   # + wallpapers input (flake=false)
modules/wm/hyprland.nix                      # SYSTEM: programs.hyprland + withUWSM,
                                             #   greetd+tuigreet, polkit
modules/home-manager/wm/hyprland/
  default.nix                                # HM: hyprland.settings (port of confs),
                                             #   services.hyprpaper, programs.hyprlock,
                                             #   systemd user units (quickshell,
                                             #   monitor-watcher), packages, env,
                                             #   xdg.configFile for scripts + quickshell
  scripts/                                   # *.sh verbatim (minus set-theme/theme-watcher),
                                             #   setup-monitors.sh patched for WALLPAPER_DIR
  quickshell/                                # QML verbatim
```

Wired: `modules/wm/hyprland.nix` into `modules/modules.nix`; HM module into
`modules/home-manager/home.nix`.

## Config mapping (conf → nix)

| Source | Target |
|---|---|
| theme.conf (general/decoration/animations/misc/master) | `hyprland.settings.{general,decoration,animations,misc,master}` |
| input.conf | `settings.input`, `settings.gesture`, `settings.binds`, `settings.device` |
| binds.conf | `settings.{bind,bindm,bindel,bindl}` (lists) |
| rules.conf | `settings.windowrule` |
| monitors.conf | `settings.monitor` (static fallback; externals via setup-monitors.sh) |
| programs.conf | `settings."$terminal"` etc. (variables) |
| startup.conf | `settings.exec-once` (minus theme switcher; + qs-theme one-shot) |
| variables.conf / uwsm/env | `settings.env` / `home.sessionVariables` (drop kde/breeze) |
| hypridle.conf | `services.hypridle` — **enable=false** (was disabled in cachy) |
| hyprpaper.conf | `services.hyprpaper.settings` (eDP wallpaper; externals at runtime) |
| hyprlock.conf | `programs.hyprlock.settings` |

## Packages (nix)

hyprland (system), uwsm, quickshell, hyprpaper, hypridle, hyprlock,
hyprpolkitagent, cliphist, wl-clipboard, grim, slurp, brightnessctl, playerctl,
jq, socat, libnotify, kitty, **yazi**, gruvbox-gtk-theme, papirus-icon-theme.
wireplumber (`wpctl`) already present via pipewire.

## systemd user services (HM, nix-native)

- `quickshell` — `quickshell -p ~/.config/quickshell/bar`, bound to graphical-session.
- `monitor-watcher` — `bash ~/.config/hypr/monitor-watcher.sh`; `path` includes
  socat, jq, hyprland, coreutils, bash, systemd (no interactive PATH inheritance).
- hyprpaper handled by `services.hyprpaper`.

## Verification (on thinkpad)

- Local: `nix-instantiate --parse` on all new `.nix`.
- Real: build, log in via tuigreet → hyprland. Check: bar (quickshell), wallpaper,
  binds, screenshots, multi-monitor hotplug, lock (SUPER SHIFT L). `nh os switch`.

## Risks

- Quickshell QML may reference fonts/icons or assume paths — verify the bar renders.
- Monitor scripts are tuned to a specific dock/Samsung setup; behave as no-op on a
  single display (offsets fall through to default). Fine for laptop-only use.
