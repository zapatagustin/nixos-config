# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Single-host NixOS flake for a ThinkPad. Host/user/hostname are all `thinkpad`. CachyOS kernel, Home Manager as a NixOS module, no desktop environment (DE/compositor removed — gaming and flatpak modules are commented out until one is re-added).

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
  → configuration.nix          # users, imports /etc/nixos/hardware-configuration.nix (NOT in repo)
    → default.nix              # ssh, fonts, printing, kernel
      → modules/modules.nix    # imports the system modules below
      → hosts/host.nix         # nix settings, programs, gc, firewall, stateVersion
  + home-manager module → modules/home-manager/home.nix
```

- **System modules** live under `modules/` and are wired via `modules/modules.nix` (boot, containers, dev, hardware, performance). `gaming/` exists but is commented out.
- **Home Manager** is configured inline in `flake.nix` for user `thinkpad`. Its root is `modules/home-manager/home.nix`, which only imports `shells/` and `terminals/`.
- **Orphaned configs:** `modules/home-manager/editors/` (neovim + full lua config, zed) is NOT imported anywhere. Editing it has no effect until added to an `imports`. The neovim setup is a standalone lua config (mason/lsp/dap), not Nix-managed plugins.

`hardware-configuration.nix` is referenced from `/etc/nixos/` and is intentionally outside the repo — don't try to create it here.

## Inputs

`nixpkgs` (unstable), `home-manager`, `chaotic` (chaotic-cx/nyx — provides CachyOS packages), `zen-browser`. `inputs` is threaded through via `specialArgs`/`extraSpecialArgs`, so modules can take `inputs` as an arg (e.g. `inputs.zen-browser.packages...` in `home.nix`).

## Conventions

- Two git identities exist: flake commits use `zapatagustin`; the HM `programs.git` block sets `zapatagustin4@gmail.com` for the built system.
- Disabled-not-deleted: dead config is left in place with a `# disabled until ...` comment rather than removed. Follow that pattern.
- `stateVersion` is `26.05` in both system and HM — don't bump casually.
