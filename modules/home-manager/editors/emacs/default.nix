{ pkgs, config, lib, ... }:
let
  # Doom core is pinned here, not floated. An unpinned clone drifts: the first
  # activation takes whatever HEAD was that day, and the `[ ! -d ]` guard means
  # it is never touched again -- surface and thinkpad end up on different Doom
  # revisions with nothing recording or reporting it. Bump this deliberately,
  # then run `doom sync`. Nix owns the revision now, so `doom upgrade` will not
  # stick across a rebuild.
  doomRev = "77318fc188cd98ebf49736664a17ccac686dca24";
  doomUrl = "https://github.com/doomemacs/core.git";
  doomDir = "${config.xdg.configHome}/emacs";
in
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

  # Fetch doom core and hold it at doomRev. Doom v3 writes into $EMACSDIR
  # (.local/, profiles/, server/), so this stays a real writable checkout in
  # $HOME rather than a store symlink -- what the pin buys is that the revision
  # is declared and converges on every host.
  # NOTE: first-time setup is `doom sync`, NOT `doom install`/`doom-install` —
  # on Doom v3 core the install CLI evaluates init.el's `doom!` before
  # doom-modules-initialize runs, crashing with "(hash-table-p nil)".
  # doom v3 keeps its modules in a submodule (sources/doom+), hence --recursive.
  home.activation.doomEmacsCore = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    (
      # Activation has no unlocked ssh key, and programs.git rewrites
      # https://github.com/ to git@github.com:, so ignore the user's gitconfig
      # entirely and fetch over real https. Also keeps the submodule URLs from
      # .gitmodules from being rewritten (`submodule sync`).
      export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
      PATH="${pkgs.git}/bin:$PATH"
      dir="${doomDir}"

      if [ ! -e "$dir/.git" ]; then
        run mkdir -p "$dir"
        run git -C "$dir" init -q
        run git -C "$dir" remote add origin ${doomUrl}
      fi

      if [ "$(git -C "$dir" rev-parse HEAD 2>/dev/null || true)" = "${doomRev}" ]; then
        exit 0
      fi

      # A dirty checkout is the user's local work: report it and leave it alone.
      # Aborting the whole activation over an emacs directory would block an
      # unrelated rebuild, and the warning names the fix.
      if [ -n "$(git -C "$dir" status --porcelain --untracked-files=no 2>/dev/null || true)" ]; then
        warnEcho "doom core in $dir has uncommitted changes, so it stays at $(git -C "$dir" rev-parse --short HEAD) instead of ${doomRev}. Commit or discard them, then rebuild."
        exit 0
      fi

      run git -C "$dir" fetch --depth 1 ${doomUrl} ${doomRev}
      run git -C "$dir" checkout -q --detach ${doomRev}
      run git -C "$dir" submodule sync --recursive -q
      run git -C "$dir" submodule update --init --recursive --depth 1
      noteEcho "doom core is at ${doomRev}. Run 'doom sync'."
    )
  '';
}
