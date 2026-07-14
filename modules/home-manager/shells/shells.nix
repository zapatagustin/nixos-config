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
  programs.gh.enable = true;
  programs.nix-index.enable = true;

  programs.eza = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.git = {
    enable = true;
    settings.user.name = "zapatagustin";
    settings.user.email = "zapatagustin4@gmail.com";
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };
}
