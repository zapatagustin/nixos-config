{ pkgs, hostname, flakePath, ... }: {
  home.packages = with pkgs; [ fastfetch ];

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
