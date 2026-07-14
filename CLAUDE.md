# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Single-host NixOS flake for a ThinkPad. Host/user/hostname are all `thinkpad`. CachyOS kernel, Home Manager as a NixOS module. Hyprland (Wayland compositor, uwsm-managed, no full DE) with a custom quickshell bar; gaming and flatpak are enabled.

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
flake.nix
  → configuration.nix          # users, imports ./hardware-configuration.nix (in repo, git-tracked)
    → default.nix              # ssh, fonts, printing, kernel
      → modules/modules.nix    # imports the system modules below
      → hosts/host.nix         # nix settings, programs, gc, firewall, stateVersion
  + home-manager module → modules/home-manager/home.nix
```

- **System modules** live under `modules/` and are wired via `modules/modules.nix` (boot, containers, dev, hardware, gaming, performance, theme/stylix, wm/hyprland). `secrets/sops.nix` exists but is commented out until `secrets/secrets.yaml` is created.
- **Home Manager** is configured inline in `flake.nix` for user `thinkpad`. Its root is `modules/home-manager/home.nix`, which imports `shells/`, `terminals/`, `editors/neovim`, and `wm/hyprland`.
- **neovim** (`modules/home-manager/editors/neovim`) is Nix-managed: `programs.neovim` with nixpkgs plugins and LSP servers on PATH (no Mason). The per-plugin lua lives inline plus `lua/*.lua` files loaded via `initLua`/`fileContents`.
- **Hyprland HM module** (`modules/home-manager/wm/hyprland`) deploys the `quickshell/` bar config (only `bar/` is actually run, via the `quickshell.service` user unit) and `scripts/`. Several monitor/group scripts are disabled until a second monitor is re-added.

`hardware-configuration.nix` is copied into the repo (git-tracked) and imported via a relative path, so rebuilds work without `--impure`. If hardware changes, regenerate it (`nixos-generate-config --show-hardware-config`) and overwrite the repo copy.

## Inputs

`nixpkgs` (unstable), `home-manager`, `chaotic` (chaotic-cx/nyx — provides CachyOS packages), `zen-browser`. `inputs` is threaded through via `specialArgs`/`extraSpecialArgs`, so modules can take `inputs` as an arg (e.g. `inputs.zen-browser.packages...` in `home.nix`).

## Conventions

- Two git identities exist: flake commits use `zapatagustin`; the HM `programs.git` block sets `zapatagustin4@gmail.com` for the built system.
- Disabled-not-deleted: dead config is left in place with a `# disabled until ...` comment rather than removed. Follow that pattern.
- `stateVersion` is `26.05` in both system and HM — don't bump casually.
