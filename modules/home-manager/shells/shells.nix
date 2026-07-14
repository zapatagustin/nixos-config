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
  # bat gets no stylix theme: homeManagerIntegration.autoImport is off (see
  # modules/theme/stylix.nix), so bat falls back to its built-in default —
  # which also avoids the ~2s batCache rebuild on every activation.
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
