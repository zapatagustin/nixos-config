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
  # bat theme (base16-stylix) comes from stylix.targets.bat
  # (modules/home-manager/stylix.nix). Trade-off: adds a ~2s batCache rebuild on
  # activation, accepted for a palette that matches the rest of the system.
  programs.gh.enable = true;
  programs.nix-index.enable = true;

  programs.eza = {
    enable = true;
    enableZshIntegration = true;
  };

  # Two GitHub identities routed by directory: personal is the default,
  # anything under ~/work/ uses the work identity. Auth (which SSH key) is
  # routed separately by remote host alias — see programs.ssh below.
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "zapatagustin";
        email = "zapatagustin4@gmail.com";
      };
      # Route any github.com remote (including https clones) through the
      # personal SSH host by default, so the personal key is used regardless
      # of how the remote was written — no dependence on `gh`'s active account.
      url."git@github.com:".insteadOf = "https://github.com/";
    };
    includes = [
      {
        condition = "gitdir:~/work/";
        contents = {
          user = {
            name = "zapataagustin";
            email = "agustin.zapata@atlas.red";
          };
          # Under ~/work, rewrite both https and plain github.com SSH remotes
          # to the work host alias, so pushes use the work key automatically.
          url."git@github-work:".insteadOf = [
            "https://github.com/"
            "git@github.com:"
          ];
        };
      }
    ];
  };

  # Multi-account GitHub over SSH. Personal is the plain github.com host
  # (default key); work repos clone from the `github-work` alias so pushes use
  # the work key. GitHub requires a distinct key per account. Keys are
  # generated imperatively into ~/.ssh (id_ed25519_personal / _work) and each
  # public key must be added to its own GitHub account.
  #
  # Written as a plain config file rather than via programs.ssh: that module's
  # matchBlocks/default-config schema is mid-deprecation on this HM version, so
  # a direct file avoids the churn. ssh accepts the store symlink (root-owned,
  # not world-writable).
  home.file.".ssh/config".text = ''
    Host github.com
      HostName github.com
      User git
      IdentityFile ~/.ssh/id_ed25519_personal
      IdentitiesOnly yes

    Host github-work
      HostName github.com
      User git
      IdentityFile ~/.ssh/id_ed25519_work
      IdentitiesOnly yes

    # Host-to-host SSH. Both keys are authorized on both hosts (see
    # configuration.nix), but neither is named id_ed25519, so ssh would only
    # offer the default names and fail with "Permission denied (publickey)" —
    # sshd has PasswordAuthentication off, so there is no fallback. Per host,
    # the username equals the hostname.
    Host surface
      User surface
      IdentityFile ~/.ssh/id_ed25519_personal
      IdentitiesOnly yes

    Host thinkpad
      User thinkpad
      IdentityFile ~/.ssh/id_ed25519_personal
      IdentitiesOnly yes
  '';

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
  };
}
