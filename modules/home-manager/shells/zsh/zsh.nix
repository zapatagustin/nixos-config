{ lib, hostname, username, flakePath, ... }: {
  # Character sheet: `sheet` prints it on demand, the zsh init below shows it once
  # per terminal window. No logo; keys in gold (ANSI yellow, stylix maps it to base0A).
  # Closed box, 40 columns (8x16 VGA font). Every value is padded AND truncated to
  # a fixed width by fastfetch width specifiers: `{field<N}` left-aligns, `{field>N}`
  # right-aligns (a longer value is cut to N). Rows are 11 columns of "│ Key  " prefix +
  # 28 of value + the closing bar. The Name row has no combined placeholder, so it is
  # built in Nix from username/hostname. Only CP437 box glyphs, VGA8 renders them.
  programs.fastfetch = {
    enable = true;
    settings = {
      logo.type = "none";
      display = {
        separator = "  ";
        color.keys = "yellow";
      };
      modules =
        let
          row = type: key: format: { inherit type; format = "${format}│"; key = "│ ${key}"; };
          name = "${username}@${hostname}";
        in
        [
          { type = "custom"; format = "┌─ CHARACTER SHEET ────────────────────┐"; }
          {
            type = "custom";
            key = "│ Name   ";
            format = "${name}${lib.strings.replicate (28 - builtins.stringLength name) " "}│";
          }
          (row "os" "Class  " "{pretty-name<28}")
          (row "kernel" "Level  " "{release<28}")
          (row "uptime" "XP     " "{days>2}d {hours>2}h {minutes>2}m                 ")
          (row "memory" "HP     " "{used>10} / {total<15}")
          (row "disk" "MP     " "{size-used>10} / {size-total<15}")
          (row "shell" "Gear   " "{pretty-name<28}")
          (row "terminal" "       " "{pretty-name<28}")
          (row "wm" "       " "{pretty-name<28}")
          (row "packages" "Gold   " "{all<28}")
          { type = "custom"; format = "└──────────────────────────────────────┘"; }
        ];
    };
  };

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;

    # compinit -C skips the compaudit security scan, which stat()s every
    # completion file on each shell start (~250ms). Pointless here: completions
    # live in the immutable, root-owned /nix/store. Drop ~/.zcompdump to force
    # a rebuild if completions ever look stale.
    completionInit = "autoload -U compinit && compinit -C";

    shellAliases = {
      ll = "eza -l";
      sheet = "fastfetch";
      # nixos-rebuild-ng runs nix as us and only elevates the activation step,
      # but ONLY if told how: --ask-sudo-password (= --elevate=sudo + prompt).
      # Without it, it never elevates → "Permission denied" on the profile
      # symlink. Do NOT prefix `sudo` (ng reexecs down to us and still won't
      # reelevate). Run as the user, let ng handle the sudo prompt itself.
      # flakePath/hostname come from extraSpecialArgs (flake.nix): home.nix is the
      # same file for both hosts, so a hardcoded path + #surface rebuilt the wrong
      # host on thinkpad.
      nixos-install = "nixos-rebuild switch --flake ${flakePath}#${hostname} --ask-sudo-password";

      cl = "claude --dangerously-skip-permissions";
      # full system update: bump flake inputs (as user — flake.lock is ours) + rebuild
      nixos-update = "cd ${flakePath} && nix flake update && nixos-rebuild switch --flake .#${hostname} --ask-sudo-password";
      # wipe garbage: delete old generations (system + user), collect garbage, dedup the store
      nixos-garbage = "sudo nix-collect-garbage -d && nix-collect-garbage -d && sudo nix store optimise";
    };

    defaultKeymap = "viins";

    history = {
      expireDuplicatesFirst = true;
      save = 10000;
      size = 10000;
      path = "$HOME/.zsh_history";
    };

    initContent = ''
      # Show the character sheet once per terminal window. Terminals here start zsh
      # directly (zellij is launched by hand, not autostarted), so the window's first
      # shell has SHLVL<=1. Sub-shells, `nix develop`/`nix shell` shells and every
      # zellij pane (SHLVL>=2, plus ZELLIJ set) are skipped, as are non-interactive
      # shells and anything with stdout not on a tty.
      if [[ -o interactive && -t 1 && -z "$ZELLIJ" && -z "$HERDR_ENV" && "''${SHLVL:-1}" -le 1 ]]; then
        fastfetch
      fi

      # nvim + agents workspace, run from a repo. `dev [vco] [-w branch]` opens a
      # herdr tab with any mix of neovim (v), Claude Code (c) and omp (o), all
      # three by default, optionally in a new sibling worktree (see shells/herdr).
      # From a bare terminal it starts the herdr server when none answers, makes
      # the tab and attaches. Inside zellij it is a new tab from the zellij layout
      # `dev` (see shells/zellij/layouts) instead, which ignores the arguments.
      dev() {
        if [[ -n "$HERDR_ENV" ]]; then
          herdr-dev "$@"
        elif [[ -n "$ZELLIJ" ]]; then
          zellij action new-tab --layout dev --cwd "$PWD"
        else
          # Started the way `herdr` starts its own server, in a session of its
          # own. Not left to herdr-dev: panes inherit the server's environment,
          # so it has to be this shell's and not the script's.
          if ! herdr workspace list >/dev/null 2>&1; then
            setsid -f herdr server >/dev/null 2>&1 </dev/null
            repeat 50; do
              herdr workspace list >/dev/null 2>&1 && break
              sleep 0.1
            done
          fi
          herdr-dev "$@" >/dev/null && herdr
        fi
      }

      # PROTOTYPE, to compare with `dev`: neovim as the multiplexer (see
      # editors/neovim/lua/mux.lua). `vdev` opens the space of the current
      # directory in one long-lived headless nvim and attaches to it: a sidebar
      # with every space and its agents, and the start screen to launch them
      # from. `vdev cov` also opens claude (c), omp (o) and the notes (v) right
      # away. :detach or closing the terminal leaves it all running. From a
      # terminal inside that nvim it only opens the space.
      vdev() {
        local sock="''${XDG_RUNTIME_DIR:-/tmp}/nvim-mux.sock"
        local spec=''${1:-}
        if [[ ! "$spec" =~ '^[vco]*$' ]]; then
          echo "usage: vdev [SPEC]   SPEC = letters c o v (claude, omp, notes)" >&2
          return 2
        fi
        # A vim string: a single quote inside it is written twice.
        local q="'"
        local dir=''${PWD//$q/$q$q}
        local open="v:lua.Mux.open('$dir', '$spec')"
        if [[ "$NVIM" == "$sock" ]]; then
          nvim --server "$sock" --remote-expr "$open" >/dev/null
          return
        fi
        if ! nvim --server "$sock" --remote-expr 1 >/dev/null 2>&1; then
          # Its own session, like the herdr server: it must outlive this terminal.
          rm -f "$sock"
          setsid -f nvim --headless --listen "$sock" --cmd 'let g:mux = 1' >/dev/null 2>&1 </dev/null
          repeat 50; do
            nvim --server "$sock" --remote-expr 1 >/dev/null 2>&1 && break
            sleep 0.1
          done
        fi
        nvim --server "$sock" --remote-expr "$open" >/dev/null && nvim --server "$sock" --remote-ui
      }

      ZSH_AUTOSUGGEST_STRATEGY=(history match_prev_cmd completion)
      ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=180'

      setopt INC_APPEND_HISTORY

      bindkey "^[[1;5C" forward-word
      bindkey "^[[1;5D" backward-word
      bindkey "\e[1~" beginning-of-line
      bindkey "\e[4~" end-of-line
      bindkey "\e[3~" delete-char
      bindkey "\e[H" beginning-of-line
      bindkey "\e[F" end-of-line
    '';
  };
}
