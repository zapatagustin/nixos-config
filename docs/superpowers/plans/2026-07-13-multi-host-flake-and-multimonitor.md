# Multi-host flake + multimonitor opt-in module — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert this single-host flake into a two-host flake (`surface`, `thinkpad`) sharing one config, gate the dual-Samsung multimonitor logic behind an opt-in flag (on only for `surface`), and fold in the open config gaps vs `cachy-config`.

**Architecture:** A `mkHost` helper in `flake.nix` builds one `nixosConfiguration` per host with `username = hostname`. Each host imports the shared `configuration.nix`, which keeps importing the machine-local `/etc/nixos/hardware-configuration.nix` (each machine rebuilds itself). Multimonitor becomes a home-manager option `myDesktop.multiMonitor.enable`; when off, its systemd service, monitor `configFile`s, startup call and TV-HDR bits are not generated. Only `monitor-watcher` (the sole script behind a systemd unit) becomes a `writeShellApplication`; the detect/setup/bind-helper scripts stay as sibling `configFile`s because `monitors-detect.sh` is `source`d by five of them.

**Tech Stack:** Nix flakes, NixOS modules, home-manager (as a NixOS module), Hyprland, Stylix, `pkgs.writeShellApplication`.

## Global Constraints

- **No test suite.** Validation is `nix flake check` (eval) + `nixos-rebuild build --flake .#<host>` (build, no activation). Never `switch` in this plan — activation is the user's manual call.
- **Flakes are enabled system-wide** (`hosts/host.nix`). If a `nix` command errors with "experimental feature disabled" or "/nix/store: Permission denied" inside the agent sandbox, re-run it with the sandbox disabled (`dangerouslyDisableSandbox: true`) — these commands are read/build only.
- **Formatting:** `nix fmt` (nixpkgs-fmt) before every commit that touches `.nix`.
- **Commits:** Conventional Commits. **No `Co-Authored-By` / no AI attribution** (user rule).
- **`stateVersion = "26.05"`** in both system and HM — do not bump.
- **Disabled-not-deleted convention:** dead config stays with a `# disabled until …` comment. (Does not apply to the intentional removals here — those are real deletions the design approved.)
- **username = hostname** per host (`surface`→`/home/surface`, `thinkpad`→`/home/thinkpad`).
- The repo is on branch `multi-host-multimonitor`. Stay on it.

---

## File Structure

- `flake.nix` — MODIFY: add `mkHost`, define `nixosConfigurations.{surface,thinkpad}`.
- `hosts/surface/default.nix` — CREATE: per-host entry, sets `multiMonitor.enable = true`.
- `hosts/thinkpad/default.nix` — CREATE: per-host entry (flag left at default `false`).
- `hosts/host.nix` — MODIFY: `NH_FLAKE` → `/home/${username}/nixos-config`.
- `configuration.nix` — UNCHANGED (already parametrized; keeps `/etc/nixos` import).
- `modules/home-manager/options.nix` — CREATE: declares `myDesktop.multiMonitor.enable`.
- `modules/home-manager/home.nix` — MODIFY: import `./options.nix`.
- `modules/home-manager/wm/hyprland/default.nix` — MODIFY: gating, `monitor-watcher` as `writeShellApplication`, `direct_scanout`, TV-HDR (gated).
- `modules/home-manager/wm/hyprland/scripts/monitor-watcher.sh` — MODIFY: `SETUP` path.
- `modules/home-manager/wm/hyprland/scripts/tv-scale.sh` — CREATE: copied from `cachy-config`.
- `modules/theme/stylix.nix` — MODIFY: add `stylix.cursor`.
- `modules/home-manager/wm/hyprland/quickshell/bar/shell.qml` — MODIFY: sync from cachy.
- `modules/home-manager/wm/hyprland/quickshell/IpcWatcher.qml` — CREATE: from cachy.

---

## Task 1: Multi-host flake skeleton

**Files:**
- Modify: `flake.nix`
- Create: `hosts/surface/default.nix`, `hosts/thinkpad/default.nix`
- Modify: `hosts/host.nix`

**Interfaces:**
- Produces: `nixosConfigurations.surface`, `nixosConfigurations.thinkpad`. Each host module file imports `../../configuration.nix`. `specialArgs`/`extraSpecialArgs` expose `hostname` and `username = hostname`.

- [ ] **Step 1: Rewrite `flake.nix` outputs with `mkHost`**

Replace the `outputs` block (keep `description` and `inputs` as-is except the description string):

```nix
  description = "multi-host NixOS flake (surface + thinkpad)";
```

```nix
  outputs = { nixpkgs, home-manager, chaotic, ... }@inputs:
    let
      mkHost = hostname:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs hostname; username = hostname; };
          modules = [
            ./hosts/${hostname}/default.nix
            chaotic.nixosModules.default
            inputs.stylix.nixosModules.stylix
            inputs.sops-nix.nixosModules.sops
            home-manager.nixosModules.home-manager
            {
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit inputs hostname; username = hostname; };
              home-manager.users.${hostname} = import ./modules/home-manager/home.nix;
            }
          ];
        };
    in
    {
      nixosConfigurations = {
        surface = mkHost "surface";
        thinkpad = mkHost "thinkpad";
      };

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
    };
```

- [ ] **Step 2: Create `hosts/surface/default.nix`**

```nix
{ ... }:
{
  imports = [ ../../configuration.nix ];
  # surface docks to 2x Samsung LF27T35 → multimonitor flag set in Task 2
}
```

- [ ] **Step 3: Create `hosts/thinkpad/default.nix`**

```nix
{ ... }:
{
  imports = [ ../../configuration.nix ];
  # nomad laptop: never docks → multiMonitor stays at its default (false)
}
```

- [ ] **Step 4: Fix `NH_FLAKE` in `hosts/host.nix`**

Change the function head to accept `username`, and the env value:

`hosts/host.nix:1` — `{ pkgs, lib, ... }:` → `{ pkgs, lib, username, ... }:`

`hosts/host.nix:45` — replace:

```nix
      NH_FLAKE = "/home/thinkpad/nixos-config";  # nh os switch w/o passing path
```

with:

```nix
      NH_FLAKE = "/home/${username}/nixos-config";  # nh os switch w/o passing path
```

- [ ] **Step 5: Format**

Run: `nix fmt`
Expected: reformats touched files, exit 0.

- [ ] **Step 6: Eval-check both hosts**

Run: `nix flake check`
Expected: no errors. (If sandboxed: re-run with sandbox disabled.)

- [ ] **Step 7: Build the local host**

Run: `nixos-rebuild build --flake .#surface`
Expected: builds a `result` symlink, exit 0, no activation. (This machine is the Surface; building `.#surface` uses the local `/etc/nixos/hardware-configuration.nix`.)

- [ ] **Step 8: Commit**

```bash
git add flake.nix hosts/surface/default.nix hosts/thinkpad/default.nix hosts/host.nix
git commit -m "feat: multi-host flake (surface + thinkpad) via mkHost"
```

---

## Task 2: `multiMonitor` option + gating

**Files:**
- Create: `modules/home-manager/options.nix`
- Modify: `modules/home-manager/home.nix`
- Modify: `modules/home-manager/wm/hyprland/default.nix`
- Modify: `hosts/surface/default.nix`

**Interfaces:**
- Produces: HM option `myDesktop.multiMonitor.enable` (bool, default `false`). Consumed in `wm/hyprland/default.nix` as `config.myDesktop.multiMonitor.enable`.
- Consumes: nothing from Task 1 beyond the host files existing.

- [ ] **Step 1: Create the option module `modules/home-manager/options.nix`**

```nix
{ lib, ... }:
{
  options.myDesktop.multiMonitor.enable = lib.mkEnableOption
    "dual-Samsung dock multimonitor daemon + TV HDR (docking host only)";
}
```

- [ ] **Step 2: Import it in `modules/home-manager/home.nix`**

Add `./options.nix` to the `imports` list (`home.nix:3-8`):

```nix
  imports = [
    ./options.nix
    ./shells/shells.nix
    ./terminals/terminals.nix
    ./editors/neovim
    ./wm/hyprland
  ];
```

- [ ] **Step 3: Add `config` + `mm` binding to `wm/hyprland/default.nix`**

Change the module head (`default.nix:1`) to take `config`:

```nix
{ pkgs, lib, config, ... }:
```

In the `let` block (`default.nix:2-7`), add after the `walls` line:

```nix
  mm = config.myDesktop.multiMonitor.enable;
```

- [ ] **Step 4: Gate the `setup-monitors` startup call in `exec-once`**

Replace the `exec-once` list (`default.nix:94-101`) so the setup call is conditional:

```nix
      exec-once = [
        "uwsm finalize HYPRLAND_INSTANCE_SIGNATURE"
        "systemctl --user start hyprpolkitagent"
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
        "echo dark > /tmp/qs-theme" # Stylix is fixed-dark; tell quickshell
      ] ++ lib.optional mm "bash ~/.config/hypr/setup-monitors.sh";
```

- [ ] **Step 5: Gate the `monitor-watcher` systemd service**

Wrap the service (`default.nix:310-326`) in `lib.mkIf mm`:

```nix
  systemd.user.services.monitor-watcher = lib.mkIf mm {
    Unit = {
      Description = "Hyprland monitor hotplug watcher";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.bash}/bin/bash %h/.config/hypr/monitor-watcher.sh";
      Environment = [
        "WALLPAPER_DIR=${walls}"
        "PATH=${lib.makeBinPath [ pkgs.bash pkgs.coreutils pkgs.socat pkgs.jq pkgs.procps pkgs.systemd pkgs.hyprland pkgs.hyprpaper ]}"
      ];
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
```

(The `writeShellApplication` conversion is Task 3 — this task only gates the existing form.)

- [ ] **Step 6: Gate the `setup-monitors.sh` configFile**

Split `xdg.configFile` (`default.nix:329-339`) so `setup-monitors.sh` is conditional and everything else stays unconditional:

```nix
  xdg.configFile = {
    "hypr/monitors-detect.sh".source = ./scripts/monitors-detect.sh;
    "hypr/switch-monitor.sh".source = ./scripts/switch-monitor.sh;
    "hypr/switch-group.sh".source = ./scripts/switch-group.sh;
    "hypr/move-to-group.sh".source = ./scripts/move-to-group.sh;
    "hypr/move-all-to-group.sh".source = ./scripts/move-all-to-group.sh;
    "hypr/screenshot.sh".source = ./scripts/screenshot.sh;
    "hypr/monitor-watcher.sh".source = ./scripts/monitor-watcher.sh;
    "quickshell".source = ./quickshell;
  } // lib.optionalAttrs mm {
    "hypr/setup-monitors.sh".source = ./scripts/setup-monitors.sh;
  };
```

(`monitor-watcher.sh` stays a configFile here; Task 3 removes it. `monitors-detect.sh` and the bind helpers stay UNCONDITIONAL — the workspace binds call the helpers on both hosts, and the helpers `source` detect.)

- [ ] **Step 7: Set the flag on `surface`**

`hosts/surface/default.nix` — add the setter:

```nix
{ username, ... }:
{
  imports = [ ../../configuration.nix ];
  # surface docks to 2x Samsung LF27T35 → enable the multimonitor daemon + TV HDR
  home-manager.users.${username}.myDesktop.multiMonitor.enable = true;
}
```

- [ ] **Step 8: Format + eval-check**

Run: `nix fmt && nix flake check`
Expected: exit 0.

- [ ] **Step 9: Build both hosts**

Run: `nixos-rebuild build --flake .#surface`
Expected: exit 0.
Run: `nixos-rebuild build --flake .#thinkpad`
Expected: exit 0. (Approximate hw — evaluates against the local machine's hardware; a successful build is the gate.)

- [ ] **Step 10: Verify the gate on thinkpad**

Run: `nix eval .#nixosConfigurations.thinkpad.config.home-manager.users.thinkpad.systemd.user.services --apply 'svcs: builtins.hasAttr "monitor-watcher" svcs'`
Expected: `false` (service not generated on thinkpad).
Run: `nix eval .#nixosConfigurations.surface.config.home-manager.users.surface.systemd.user.services --apply 'svcs: builtins.hasAttr "monitor-watcher" svcs'`
Expected: `true`.

- [ ] **Step 11: Commit**

```bash
git add modules/home-manager/options.nix modules/home-manager/home.nix modules/home-manager/wm/hyprland/default.nix hosts/surface/default.nix
git commit -m "feat: multiMonitor opt-in flag, gated to surface"
```

---

## Task 3: `monitor-watcher` → `writeShellApplication`

**Files:**
- Modify: `modules/home-manager/wm/hyprland/scripts/monitor-watcher.sh`
- Modify: `modules/home-manager/wm/hyprland/default.nix`

**Interfaces:**
- Consumes: `mm` binding + gated service from Task 2.
- Produces: a `monitorWatcher` derivation; the systemd unit references `${monitorWatcher}/bin/monitor-watcher` and no longer sets `PATH` manually.

- [ ] **Step 1: Point `SETUP` at the config path**

`scripts/monitor-watcher.sh:8` — replace:

```bash
SETUP="$(dirname "$0")/setup-monitors.sh"
```

with:

```bash
SETUP="$HOME/.config/hypr/setup-monitors.sh"
```

(The watcher now lives in the nix store; `dirname $0` would resolve to the store dir. `setup-monitors.sh` stays deployed at `~/.config/hypr/` by Task 2.)

- [ ] **Step 2: Define the `monitorWatcher` derivation**

In `wm/hyprland/default.nix`, add to the `let` block (after `mm`):

```nix
  monitorWatcher = pkgs.writeShellApplication {
    name = "monitor-watcher";
    # deps for the watcher AND for the setup-monitors.sh it spawns (child inherits PATH)
    runtimeInputs = with pkgs; [ socat systemd hyprland hyprpaper jq procps coreutils bash ];
    bashOptions = [ "nounset" ]; # match the script's original `set -u`; errexit would abort best-effort hyprctl/kill calls
    text = builtins.readFile ./scripts/monitor-watcher.sh;
  };
```

- [ ] **Step 3: Rewrite the systemd unit to use the store path**

Replace the `Service` block inside `systemd.user.services.monitor-watcher` (from Task 2) with:

```nix
    Service = {
      ExecStart = "${monitorWatcher}/bin/monitor-watcher";
      Restart = "on-failure";
      RestartSec = 2;
    };
```

(The `Environment = [ "WALLPAPER_DIR=…" "PATH=…" ]` block is deleted. `WALLPAPER_DIR` is already exported into the Hyprland session via `settings.env` (`default.nix:40-42`); `setup-monitors.sh`, spawned by the watcher inside that session, inherits it.)

- [ ] **Step 4: Remove `monitor-watcher.sh` from `xdg.configFile`**

In the `xdg.configFile` block, delete the line:

```nix
    "hypr/monitor-watcher.sh".source = ./scripts/monitor-watcher.sh;
```

- [ ] **Step 5: Format + eval-check (runs shellcheck on the script)**

Run: `nix fmt && nix flake check`
Expected: exit 0. `writeShellApplication` runs `shellcheck` at build time — a shell error here fails the check.

- [ ] **Step 6: Build surface**

Run: `nixos-rebuild build --flake .#surface`
Expected: exit 0.

- [ ] **Step 7: Commit**

```bash
git add modules/home-manager/wm/hyprland/scripts/monitor-watcher.sh modules/home-manager/wm/hyprland/default.nix
git commit -m "refactor: monitor-watcher as writeShellApplication (drop manual PATH)"
```

---

## Task 4: Gaps — `direct_scanout` + gruvbox cursor

**Files:**
- Modify: `modules/home-manager/wm/hyprland/default.nix`
- Modify: `modules/theme/stylix.nix`

**Interfaces:**
- Independent of other tasks (both hosts, unconditional).

- [ ] **Step 1: Add `render.direct_scanout`**

In `wm/hyprland/default.nix` `settings`, add a `render` block next to `misc` (after `default.nix:76`, the `misc` block):

```nix
      render.direct_scanout = true; # bypass compositing on fullscreen surfaces (perf; lost in the cachy port)
```

- [ ] **Step 2: Find the exact gruvbox cursor theme name**

Run:
```bash
ls "$(nix build --no-link --print-out-paths github:NixOS/nixpkgs/nixos-unstable#capitaine-cursors-themed)/share/icons"
```
Expected: a list of cursor theme directories (e.g. `Capitaine Dark`, `Capitaine Light`, and/or gruvbox-named variants). Pick the gruvbox **dark** theme directory name from the output — that exact string is the value for `name` in the next step. (If sandboxed, re-run with sandbox disabled.)

- [ ] **Step 3: Add `stylix.cursor`**

In `modules/theme/stylix.nix`, inside the `stylix = { … }` attrset (after the `fonts` block, `stylix.nix:15`), add — substituting the exact directory name from Step 2 for `<NAME>`:

```nix
    cursor = {
      package = pkgs.capitaine-cursors-themed;
      name = "<NAME>"; # exact dir from `share/icons` (Step 2) — gruvbox dark variant
      size = 24; # was XCURSOR_SIZE/HYPRCURSOR_SIZE=24 in cachy uwsm/env
    };
```

- [ ] **Step 4: Format + eval-check**

Run: `nix fmt && nix flake check`
Expected: exit 0. (An invalid `cursor.name`/`package` fails stylix eval.)

- [ ] **Step 5: Build surface**

Run: `nixos-rebuild build --flake .#surface`
Expected: exit 0.

- [ ] **Step 6: Verify the cursor env vars land**

Run: `nix eval --raw .#nixosConfigurations.surface.config.home-manager.users.surface.home.sessionVariables.XCURSOR_SIZE 2>/dev/null || echo "check stylix-set location"`
Expected: `24` (or, if stylix sets it elsewhere, confirm `XCURSOR_SIZE`/`HYPRCURSOR_SIZE` appear in the built session env). Stylix's cursor module sets both; a successful build with the cursor block is the primary gate.

- [ ] **Step 7: Commit**

```bash
git add modules/home-manager/wm/hyprland/default.nix modules/theme/stylix.nix
git commit -m "feat: restore direct_scanout + gruvbox cursor (size 24)"
```

---

## Task 5: TV 4K HDR (gated to surface)

**Files:**
- Create: `modules/home-manager/wm/hyprland/scripts/tv-scale.sh` (from `cachy-config`)
- Modify: `modules/home-manager/wm/hyprland/default.nix`

**Interfaces:**
- Consumes: `mm` binding (Task 2).
- Produces: a `tvScale` derivation; a static `HDMI-A-1` monitor line and a `SUPER SHIFT T` bind, all under `mm`.

- [ ] **Step 1: Copy `tv-scale.sh` from cachy**

Run:
```bash
cp ~/Projects/cachy-config/hypr/tv-scale.sh \
   modules/home-manager/wm/hyprland/scripts/tv-scale.sh
```
Expected: file present. (It uses `hyprctl`, `grep`, `awk`, `sleep` — no edits needed; deps come via `runtimeInputs`.)

- [ ] **Step 2: Define the `tvScale` derivation**

In `wm/hyprland/default.nix` `let` block, add:

```nix
  tvScale = pkgs.writeShellApplication {
    name = "tv-scale";
    runtimeInputs = with pkgs; [ hyprland coreutils gnugrep gawk ];
    bashOptions = [ "nounset" ]; # script uses `set -u`
    text = builtins.readFile ./scripts/tv-scale.sh;
  };
```

- [ ] **Step 3: Gate the `HDMI-A-1` monitor line**

Replace the `monitor` list (`default.nix:44-47`):

```nix
      monitor = [
        "eDP-1,preferred,auto,1" # 1920x1080 native, scale 1 (no fractional); externals via setup-monitors.sh
        ",preferred,auto,auto" # fallback for unknown monitors
      ] ++ lib.optional mm
        "HDMI-A-1,3840x2160@60,0x0,2,bitdepth,10,cm,wide"; # TV 4K: 10-bit + wide gamut (SDR desktop); tv-scale toggles game/HDR
```

- [ ] **Step 4: Gate the `SUPER SHIFT T` bind**

The `bind` list ends with the `mkWsBinds` concatenations (`default.nix:143-147`). Append one more `lib.optional`:

```nix
      ]
      ++ mkWsBinds "$mainMod" "switch-monitor.sh"
      ++ mkWsBinds "ALT" "switch-group.sh"
      ++ mkWsBinds "$mainMod SHIFT" "move-to-group.sh"
      ++ mkWsBinds "ALT SHIFT" "move-all-to-group.sh"
      ++ lib.optional mm "$mainMod SHIFT, T, exec, ${tvScale}/bin/tv-scale";
```

- [ ] **Step 5: Format + eval-check**

Run: `nix fmt && nix flake check`
Expected: exit 0 (shellcheck runs on `tv-scale.sh`).

- [ ] **Step 6: Build both hosts**

Run: `nixos-rebuild build --flake .#surface`
Expected: exit 0.
Run: `nixos-rebuild build --flake .#thinkpad`
Expected: exit 0 (no HDMI line, no TV bind, no `tvScale` referenced).

- [ ] **Step 7: Commit**

```bash
git add modules/home-manager/wm/hyprland/scripts/tv-scale.sh modules/home-manager/wm/hyprland/default.nix
git commit -m "feat: TV 4K HDR support (HDMI line + tv-scale), gated to surface"
```

---

## Task 6: Quickshell drift sync

**Files:**
- Modify: `modules/home-manager/wm/hyprland/quickshell/bar/shell.qml`
- Create: `modules/home-manager/wm/hyprland/quickshell/IpcWatcher.qml` (at the path matching cachy)

**Interfaces:**
- Independent. Both hosts (quickshell bar runs on both).

- [ ] **Step 1: Locate `IpcWatcher.qml` in cachy and confirm `shell.qml`'s import path**

Run:
```bash
fd IpcWatcher.qml ~/Projects/cachy-config/quickshell
rg -n 'IpcWatcher' ~/Projects/cachy-config/quickshell/bar/shell.qml
```
Expected: the `fd` output gives the source path; the `rg` output shows how `shell.qml` imports/instantiates `IpcWatcher` (relative path decides where the copy must land under `.../hyprland/quickshell/`).

- [ ] **Step 2: Copy `shell.qml` (refactored version) from cachy**

Run:
```bash
cp ~/Projects/cachy-config/quickshell/bar/shell.qml \
   modules/home-manager/wm/hyprland/quickshell/bar/shell.qml
```
Expected: file overwritten.

- [ ] **Step 3: Copy `IpcWatcher.qml` to the matching relative path**

Copy the file found in Step 1 to the SAME relative location under `modules/home-manager/wm/hyprland/quickshell/` that it occupies under `cachy-config/quickshell/` (so `shell.qml`'s relative import resolves). Example if it is top-level:
```bash
cp ~/Projects/cachy-config/quickshell/IpcWatcher.qml \
   modules/home-manager/wm/hyprland/quickshell/IpcWatcher.qml
```
Expected: file present at the correct relative path.

- [ ] **Step 4: Eval-check + build**

Run: `nix flake check && nixos-rebuild build --flake .#surface`
Expected: exit 0. (QML is copied verbatim as a `configFile`; the build only confirms the files are wired. Runtime rendering is verified visually after switch.)

- [ ] **Step 5: Commit**

```bash
git add modules/home-manager/wm/hyprland/quickshell/
git commit -m "chore: sync quickshell shell.qml + add IpcWatcher.qml from cachy"
```

---

## Post-implementation (manual, user-run)

Not plan steps — flagged for the user after all tasks land:

- `sudo nixos-rebuild switch --flake .#surface` on the Surface; then dock/undock and confirm `systemctl --user status monitor-watcher`, workspace/wallpaper re-apply, `SUPER+SHIFT+T` TV toggle, cursor size, and the quickshell bar render.
- On the ThinkPad: `sudo nixos-rebuild switch --flake .#thinkpad`; confirm `systemctl --user status monitor-watcher` reports **no such unit**.
- Switching the running system's username (`thinkpad` → `surface`) changes the home dir; do it deliberately (data migration is out of scope for this plan).

## Self-Review notes

- **Spec coverage:** multi-host (T1) · opt-in gating (T2) · writeShellApplication for the watcher only, per the discovered 5-script `source` constraint (T3) · direct_scanout + cursor (T4) · TV HDR gated (T5) · quickshell sync (T6). All design decisions map to a task.
- **Deviation from spec:** spec §3 was updated during planning — only `monitor-watcher` converts to `writeShellApplication` (not the whole trio), because `monitors-detect.sh` is `source`d by five scripts and inlining would break DRY / the bind helpers. Documented in the spec and in T3.
- **Cursor name** is resolved by an explicit build-time lookup (T4 Step 2), not a placeholder.
- **`nix eval` gate checks** (T2 Step 10) may need the sandbox disabled in-agent; on the real machine they run directly.
