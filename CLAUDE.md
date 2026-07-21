# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Multi-host NixOS flake: `surface` (work laptop, docks to external monitors) and `thinkpad` (nomad laptop, never docks). Per host, user and hostname equal the host name. CachyOS kernel, Home Manager as a NixOS module. Hyprland (Wayland compositor, uwsm-managed, no full DE) with a custom quickshell bar; gaming and flatpak are enabled.

## Commands

```sh
nix flake check                              # eval-check the flake
nix fmt                                       # format (nixpkgs-fmt, the flake formatter)
sudo nixos-rebuild switch --flake .#thinkpad  # build + activate
sudo nixos-rebuild build  --flake .#thinkpad  # build only, no activation
nh os switch .                                # nh wrapper (installed), nicer build output
nh os boot .                                  # activate on next boot only
```

There are no tests. Validation is `nix flake check` + a build.

## Architecture

Import tree, not a flat config. Each `.nix` is imported by its parent — adding a file does nothing until you wire it into the parent's `imports`.

```
flake.nix                      # mkHost builds nixosConfigurations.{surface,thinkpad}
  → hosts/${host}/default.nix  # per-host: imports configuration.nix, sets myDesktop.multiMonitor (surface=true)
    → configuration.nix        # users, imports ./hardware-configuration.nix (in repo, git-tracked)
      → default.nix            # ssh, fonts, printing, kernel
        → modules/modules.nix  # imports the system modules below
        → hosts/host.nix       # nix settings, programs, gc, firewall, stateVersion
  + home-manager module → modules/home-manager/home.nix
```

- **System modules** live under `modules/` and are wired via `modules/modules.nix` (boot, containers, dev, hardware, gaming, performance, theme/stylix, wm/hyprland). `secrets/sops.nix` is active (declares SOPS-backed secrets — `secrets.yaml` exists in the repo).
- **Home Manager** is wired via `flake.nix` (`mkHost`) per host. Its root is `modules/home-manager/home.nix`, which imports `shells/`, `terminals/`, `editors/neovim`, `editors/emacs`, `wm/hyprland`, `ai/`, `opencode/`, and `claude-code/`. `options.nix` declares `myDesktop.multiMonitor.enable`, read by the hyprland module.
- **neovim** (`modules/home-manager/editors/neovim`) is Nix-managed: `programs.neovim` with nixpkgs plugins and LSP servers on PATH (no Mason). The per-plugin lua lives inline plus `lua/*.lua` files loaded via `initLua`/`fileContents`.
- **Hyprland HM module** (`modules/home-manager/wm/hyprland`) deploys the `quickshell/` bar config (only `bar/` is actually run, via the `quickshell.service` user unit) and `scripts/`. The monitor-watcher unit + per-monitor/group scripts + TV-scale bind are gated behind `myDesktop.multiMonitor.enable` (surface only).
- **AI agent stack**: `ai/` installs the `opencode`/`gentle-ai`/`engram` binaries (the latter two from `pkgs/`) and idempotently installs Claude Code + opencode plugins on activation. `opencode/` and `claude-code/` manage the *declarative* config (opencode.json settings, CLAUDE.md, hooks, agents, commands, skills) via `programs.opencode`/`programs.claude-code`. Claude's `settings.json` is intentionally left manual (Claude writes it at runtime).

`hardware-configuration.nix` is copied into the repo (git-tracked) and imported via a relative path, so rebuilds work without `--impure`. If hardware changes, regenerate it (`nixos-generate-config --show-hardware-config`) and overwrite the repo copy.

## Inputs

`nixpkgs` (unstable), `home-manager`, `chaotic` (chaotic-cx/nyx — provides CachyOS packages), `zen-browser`. `inputs` is threaded through via `specialArgs`/`extraSpecialArgs`, so modules can take `inputs` as an arg (e.g. `inputs.zen-browser.packages...` in `home.nix`).

## Conventions

- Two git identities exist: flake commits use `zapatagustin`; the HM `programs.git` block sets `zapatagustin4@gmail.com` for the built system.
- Disabled-not-deleted: dead config is left in place with a `# disabled until ...` comment rather than removed. Follow that pattern.
- `stateVersion` is `26.05` in both system and HM — don't bump casually.
- Skills are duplicated per agent (`claude-code/claude/skills/` and `opencode/config/skills/`) and hand-maintained; the copies legitimately differ (opencode has an orchestrator-gate preamble, different frontmatter). After editing any skill, run `scripts/skill-drift.sh` and mirror the change to the other copy — the script reports which skills diverge and by how much (small drifts are usually accidental).
