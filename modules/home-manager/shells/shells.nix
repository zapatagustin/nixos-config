{ ... }: {
  imports = [
    ./zsh/zsh.nix
    ./starship/starship.nix
    ./zellij/zellij.nix
  ];

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.zoxide.enable = true;
  programs.bat.enable = true;
  # bat's stylix theme forces an HM `batCache` rebuild (~2s) on *every* activation,
  # i.e. every boot, on the critical path before login. Not worth it for a
  # syntax-highlighter colorscheme — bat falls back to its built-in default.
  stylix.targets.bat.enable = false;
  programs.gh.enable = true;
  programs.nix-index.enable = true;

  programs.eza = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.git = {
    enable = true;
    settings.user = {
      name = "zapatagustin";
      email = "zapatagustin4@gmail.com";
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };
}
