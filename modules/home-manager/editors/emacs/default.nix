{ pkgs, config, lib, ... }:
{
  programs.emacs = {
    enable = true;
    package = pkgs.emacs-pgtk; # native Wayland (hyprland)
    # built by nix so doom's :term vterm doesn't try to compile the C module itself
    extraPackages = epkgs: [ epkgs.vterm ];
  };

  # CLI deps doom expects on PATH (mirrors the neovim module: no self-managed installs)
  home.packages = with pkgs; [
    # doom core
    ripgrep
    fd
    # :checkers spell (+hunspell) — es_AR carries Argentine idioms; en_US for code/English.
    # Wrapper bakes DICPATH so emacs's hunspell subprocess finds the dicts.
    (hunspell.withDicts (ds: with ds; [ es_AR en_US ]))
    # :lang nix (+lsp) — nixd + nixpkgs-fmt, same as neovim
    nixd
    nixpkgs-fmt
    # :lang sh
    shellcheck
    shfmt
    bash-language-server
    # :lang org / :tools lookup
    sqlite
  ];

  # `doom` CLI (doom sync, doom doctor, ...)
  home.sessionPath = [ "${config.xdg.configHome}/emacs/bin" ];

  # doom user config is declarative, split into modules under ./doom.
  # After editing it + rebuilding, run `doom sync`.
  xdg.configFile."doom" = {
    source = ./doom;
    recursive = true;
  };

  # clone doom core once; first-time setup is `doom sync` (needs network).
  # NOTE: use `doom sync`, NOT `doom install`/`doom-install` — on Doom v3 core
  # the install CLI evaluates init.el's `doom!` before doom-modules-initialize
  # runs, crashing with "(hash-table-p nil)". `doom sync` takes the correct path.
  # doom v3 keeps its modules in a submodule (sources/doom+), hence --recurse-submodules.
  home.activation.cloneDoomEmacs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -d "${config.xdg.configHome}/emacs" ]; then
      run ${pkgs.git}/bin/git clone --depth 1 --single-branch \
        --recurse-submodules --shallow-submodules \
        https://github.com/doomemacs/core.git "${config.xdg.configHome}/emacs"
    fi
  '';
}
