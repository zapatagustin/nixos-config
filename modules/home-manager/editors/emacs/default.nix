{ pkgs, inputs, ... }:
{
  # Doom Emacs, package set and all, built by nix-doom-emacs-unstraightened.
  #
  # This replaces a hand-rolled activation script that git-cloned doomemacs/core
  # into a writable ~/.config/emacs at a pinned rev. The rev was pinned; what
  # `doom sync` then installed underneath it was not -- 142 straight.el clones in
  # ~/.config/emacs/.local, unrecorded and unreproducible. Unstraightened resolves
  # doom's package set with nix instead, so there is no straight.el, no .local,
  # and no `doom sync` step: editing ./doom means a rebuild.
  #
  # Deliberately NOT combined with programs.emacs: home-manager wraps its package
  # in emacsWithPackages, and double-wrapping the already-wrapped doom emacs
  # breaks load-path non-interactively (works when you open a window, fails under
  # the doom CLI and flycheck). Upstream documents this in HACKING.md.
  imports = [ inputs.nix-doom-emacs-unstraightened.homeModule ];

  programs.doom-emacs = {
    enable = true;
    emacs = pkgs.emacs-pgtk; # native Wayland (hyprland)
    doomDir = ./doom;
    # doom's :term vterm needs the native module; nixpkgs' epkgs.vterm already
    # builds it, so it never gets compiled at first launch.
    extraPackages = epkgs: [ epkgs.vterm ];
  };

  # CLI deps doom expects on PATH (mirrors the neovim module: no self-managed
  # installs). ripgrep/fd/git are omitted on purpose -- programs.doom-emacs
  # provides those to doom itself via extraBinPackages, and the user-facing
  # copies live in hosts/software/default_soft.nix.
  home.packages = with pkgs; [
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
}
