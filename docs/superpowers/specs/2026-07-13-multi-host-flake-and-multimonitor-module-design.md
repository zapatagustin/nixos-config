# Multi-host flake + multimonitor opt-in module — Design

**Date:** 2026-07-13
**Status:** Approved, pending implementation plan
**Supersedes (partial):** `2026-06-23-hyprland-port-design.md` — revises the
"scripts CANNOT become writeShellApplication" note for the monitor daemon trio
only (see Decisions §3).

## Goal

Turn this single-host flake into a two-host flake (`surface`, `thinkpad`) sharing
one config, and make the dual-Samsung multimonitor logic an opt-in module that
only runs on the docking host. Fold in the config gaps still open vs the
`cachy-config` source (TV HDR, `direct_scanout`, cursor size, quickshell drift).

Context: `surface` is the work laptop that docks to two Samsung LF27T35 monitors;
`thinkpad` is a nomad laptop that runs the same Hyprland desktop but never docks.
The `cachy-config` repo stays the separate gaming-desktop config and is out of scope.

## Decisions (from brainstorm)

### 1. Multi-host structure — `mkHost` helper, per-host dirs

- `flake.nix` gains a `mkHost` helper called once per host. No flake-parts — two
  machines don't justify the layer (YAGNI).
- **`username = hostname`** per host (`surface`/`surface`, `thinkpad`/`thinkpad`).
- Layout:

  ```
  flake.nix                # mkHost "surface" / mkHost "thinkpad"
  configuration.nix        # shared, parametrized by hostname/username (unchanged intent)
  hosts/
    host.nix               # shared nix settings (fix NH_FLAKE to /home/${username}/…)
    surface/default.nix    # per-host toggles: multiMonitor.enable = true
    thinkpad/default.nix   # (omits the flag → default false)
  ```

- `mkHost hostname` points its module list at `./hosts/${hostname}/default.nix`,
  which imports `../../configuration.nix` and sets per-host toggles.
- `specialArgs` and `home-manager.extraSpecialArgs` pass `inherit inputs hostname`
  and `username = hostname`.

### 2. hardware-configuration.nix — keep importing `/etc/nixos` (Option A)

- Both hosts keep `imports = [ /etc/nixos/hardware-configuration.nix ]` in
  `configuration.nix` (current behavior). The absolute path resolves at eval time
  on whichever machine runs the build → each machine gets its own hardware.
- **Model:** each machine rebuilds *itself* (`nixos-rebuild switch --flake .#surface`
  on the surface, `.#thinkpad` on the thinkpad). No remote cross-building.
- **Accepted trade-offs:**
  - Cannot correctly build the *other* host (would pick up the local machine's hw).
  - `nix flake check` evaluates both hosts; the non-local host evaluates against the
    local hw — usually evals fine, but is approximate for that host. Low assertion-
    failure risk between two similar laptops.
- No per-host hw file committed; **no manual copy step**. Switch to committed
  per-host hw only if remote build/deploy is ever needed.

### 3. Multimonitor — opt-in HM module, monitor trio → writeShellApplication

- New HM option `myDesktop.multiMonitor.enable` (`lib.mkEnableOption`, default `false`).
  - `surface`: `home-manager.users.surface.myDesktop.multiMonitor.enable = true`.
  - `thinkpad`: unset → the systemd user services and monitor `configFile`s are
    **not generated** at all (`lib.mkIf`). Zero process, zero RAM on the nomad host.
- **Only `monitor-watcher.sh` → `pkgs.writeShellApplication`** (revised during
  planning — see below). It is the sole script behind a systemd unit and thus the
  only one carrying the manual `PATH=${lib.makeBinPath …}` hack.
  - Gains: `runtimeInputs` bakes deps into PATH (kills the manual PATH line in the
    `monitor-watcher` systemd unit), build-time `shellcheck`, store-path immutable.
  - `bashOptions = [ "nounset" ]` to match the script's original `set -u` (avoid
    `errexit` aborting the best-effort `hyprctl`/`kill` calls).
  - It spawns `setup-monitors.sh`, so its `runtimeInputs` must also cover setup's
    deps (`jq hyprland hyprpaper procps coreutils bash`) since the child inherits PATH.
    `SETUP` changes from `$(dirname $0)/setup-monitors.sh` to `$HOME/.config/hypr/setup-monitors.sh`.
- **`monitors-detect.sh`, `setup-monitors.sh`, and the bind helpers stay as
  `xdg.configFile`.** DISCOVERED CONSTRAINT (revises the "trio → writeShellApplication"
  idea): `monitors-detect.sh` is `source`d by **five** scripts — `setup-monitors.sh`
  AND the four bind helpers `switch-monitor.sh` / `switch-group.sh` / `move-to-group.sh`
  / `move-all-to-group.sh`. Inlining detect into a `writeShellApplication` setup would
  either break the helpers or duplicate the detect logic. The helpers are called from
  keybinds by `~/.config/hypr/…` path (the `2026-06-23` design's bind-path constraint
  still holds). So detect + setup + helpers remain sibling files under `~/.config/hypr/`,
  relying on the session PATH — exactly as the prior port designed. Converting only
  `monitor-watcher` still achieves the real nixos-style win (no PATH hack in the unit)
  without duplication.

### 4. Hyprland is shared (both hosts)

The WM, Stylix, binds, hyprlock, hypridle and quickshell stay in the shared config
(via `modules/`). Both machines run the same desktop. Only the multimonitor daemon
and TV HDR bits are gated by `multiMonitor.enable`.

### 5. Gaps folded in

| Gap | Fix | Scope |
| --- | --- | --- |
| `render.direct_scanout` lost | add `settings.render.direct_scanout = true` | both hosts (real perf, harmless when no fullscreen surface) |
| Cursor size (`XCURSOR_SIZE`/`HYPRCURSOR_SIZE=24`) lost + no cursor theme | `stylix.cursor = { package = pkgs.capitaine-cursors-themed; name = <gruvbox theme dir>; size = 24; }` — declares both env vars + a gruvbox cursor theme | both hosts |
| TV 4K HDR support dropped | static `monitor = "HDMI-A-1,3840x2160@60,0x0,2,bitdepth,10,cm,wide"` line + `tv-scale` as `writeShellApplication` + bind `SUPER SHIFT, T` | **gated by `multiMonitor.enable`** (surface only) |
| quickshell `shell.qml` stale fork | sync `shell.qml` from cachy + add `IpcWatcher.qml` | both hosts |

- `direct_scanout` and cursor are unconditional (harmless everywhere). User chose a
  gruvbox cursor theme (`capitaine-cursors-themed`, confirmed present in nixpkgs with a
  Gruvbox variant). The exact `stylix.cursor.name` (theme dir under
  `${pkgs.capitaine-cursors-themed}/share/icons`, "Capitaine" prefix) is confirmed at
  apply time by listing that dir — not guessed in the spec.
- TV HDR lives under the same flag as the monitor daemon — it only matters on the
  docking host, and the `HDMI-A-1` line / `tv-scale` script / bind are inert when no
  TV is attached, so gating avoids shipping an unused bind on the nomad host.

## Components

- **`flake.nix`** — `mkHost` helper; `nixosConfigurations.{surface,thinkpad}`.
- **`hosts/surface/default.nix`, `hosts/thinkpad/default.nix`** — per-host entry:
  import shared config, set toggles.
- **`hosts/host.nix`** — shared nix settings; `NH_FLAKE` fixed to `/home/${username}/nixos-config`.
- **`configuration.nix`** — unchanged intent (parametrized hostname/username, keeps
  `/etc/nixos/hardware-configuration.nix` import).
- **`modules/home-manager/wm/hyprland/`** — declares `myDesktop.multiMonitor.enable`;
  monitor trio as `writeShellApplication`; services + monitor configFiles under
  `lib.mkIf`; TV HDR bits under the same guard; `direct_scanout` in settings.
- **`modules/theme/stylix.nix`** — add `stylix.cursor`.
- **quickshell** — `shell.qml` synced, `IpcWatcher.qml` added.

## Error handling / edge cases

- `multiMonitor.enable = false` (thinkpad): no monitor services, no monitor scripts,
  no TV bind. Hyprland still runs with the declarative `eDP-1` + fallback monitor lines.
- writeShellApplication `set -euo pipefail` default: the current scripts use `set -u`
  only; keep the existing tolerance (some `hyprctl` calls are best-effort, e.g.
  `moveworkspacetomonitor … 2>/dev/null`). Verify no legitimate non-zero exit trips
  `-e` — override `set` inside the script text if needed (implementation detail).
- `flake check` on a host evaluates the other host against local hw — documented,
  accepted (Decision §2).

## Out of scope

- The `thinkpad`/`surface` hostname vs `/home/agustin` checkout mismatch (rename is
  a separate concern; the built system uses `username = hostname`).
- Porting `cachy-config`'s theme switcher, gaming, or any non-Hyprland dotfiles.
- Committing per-host hardware-configuration.nix (only if remote deploy is later needed).

## Validation

- `nix flake check` (local host meaningful; other host approximate).
- `nixos-rebuild build --flake .#surface` and `.#thinkpad` where hw allows.
- On surface: dock/undock, confirm `monitor-watcher` reacts and workspaces/wallpapers
  re-apply; confirm `SUPER SHIFT T` toggles the TV mode when a TV is attached.
- On thinkpad: confirm `systemctl --user status monitor-watcher` reports no such unit.
