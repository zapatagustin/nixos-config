{ lib, pkgs, ... }: {
  home.packages = with pkgs; [ fastfetch ];

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      ll = "eza -l";
      update = "sudo nixos-rebuild switch --flake ~/Projects/nixos-config#thinkpad";
      upgrade = "cd ~/Projects/nixos-config && nix flake update && sudo nixos-rebuild switch --flake .#thinkpad";
      gc = "sudo nix-collect-garbage -d";
    };

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
      bindkey -e

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
