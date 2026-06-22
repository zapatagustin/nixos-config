# Stylix system-wide gruvbox — Design

**Date:** 2026-06-22
**Status:** Approved, pending implementation

## Goal

Apply gruvbox consistently across the whole system from a single source of
truth, including GUI apps (brave, zathura, calibre, etc.) that per-app theming
can't easily reach. No DE/compositor, so "system-wide" = TTY console + every app.

## Choice

Stylix (`github:nix-community/stylix`) over manual per-app theming: one base16
scheme drives GTK, Qt, kitty, bat, console, neovim, cursor, etc.

- Scheme: **gruvbox-dark-medium** (`pkgs.base16-schemes`).
- Polarity: dark.

## Wiring

- `flake.nix`: add input `stylix` (`inputs.nixpkgs.follows = "nixpkgs"`), add
  `inputs.stylix.nixosModules.stylix` to the host's `modules`. The NixOS module
  also themes home-manager apps automatically (HM runs as a NixOS module here).
- New `modules/theme/stylix.nix`, imported from `modules/modules.nix`.

## Config

```nix
stylix = {
  enable = true;
  polarity = "dark";
  base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";
  image = config.lib.stylix.pixel "base00";   # no DE → wallpaper is a solid bg pixel
  fonts = {
    monospace = { package = pkgs.udev-gothic; name = "UDEV Gothic"; };
    sansSerif = { package = pkgs.udev-gothic; name = "UDEV Gothic"; };
    serif     = { package = pkgs.udev-gothic; name = "UDEV Gothic"; };
  };
  targets.starship.enable = false;   # see conflict 2
};
```

`autoEnable` (default true) themes all detected targets.

## Conflicts resolved

1. **Fonts double-definition.** `default.nix` sets `fonts.fontconfig.defaultFonts`;
   Stylix sets the same option → "defined twice" error. Remove the manual
   `fontconfig.defaultFonts` block from `default.nix`; move font choice to
   `stylix.fonts`. Keep `fonts.enableDefaultPackages` and `fonts.packages = [udev-gothic]`.

2. **Starship.** Stylix's starship target imposes `palette = "stylix"` with base16
   color names. The existing prompt uses custom names (`color_orange`, `color_aqua`…)
   → would lose colors. The manual palette is already gruvbox (same hexes), so
   disable `stylix.targets.starship.enable` and keep the manual prompt. Visually
   still gruvbox; only target excluded, for technical reasons.

## Neovim changes

Stylix owns nvim colors now:
- Remove `gruvbox-nvim` plugin block + `vim.cmd.colorscheme("gruvbox")` in
  `editors/neovim/default.nix`.
- `lualine` theme `"gruvbox"` → `"auto"` (picks up stylix base16 colorscheme).

## Verification

- Local: `nix-instantiate --parse` on changed `.nix`.
- Real: on thinkpad, `nixos-rebuild switch --flake ...` (auto-adds the new input
  to `flake.lock`). Confirm: kitty/bat/TTY/GTK apps render gruvbox; `nvim` colors
  from stylix; starship prompt unchanged.

## Risks

- New flake input = bigger lock/closure. Acceptable for the consistency.
- Stylix may version-skew with nixpkgs-unstable; pin via `follows` mitigates most.
