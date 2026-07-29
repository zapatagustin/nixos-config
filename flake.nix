{
  description = "multi-host NixOS flake (surface + thinkpad)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hermes-agent.url = "github:NousResearch/hermes-agent";
    # Claude Code + opencode config. Single source of truth: this flake used to
    # carry its own copy under modules/home-manager/{claude-code,opencode},
    # which drifted from it silently.
    ecomono = {
      url = "github:zapatagustin/ecomono";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, chaotic, ... }@inputs:
    let
      mkHost = hostname:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs hostname; username = hostname; };
          modules = [
            ./hosts/${hostname}/default.nix
            chaotic.nixosModules.default
            inputs.stylix.nixosModules.stylix
            inputs.sops-nix.nixosModules.sops
            inputs.hermes-agent.nixosModules.default
            home-manager.nixosModules.home-manager
            {
              home-manager.useUserPackages = true;
              # back up (instead of clobber) pre-existing unmanaged dotfiles, e.g. ~/.zshrc -> ~/.zshrc.hm-bak
              home-manager.backupFileExtension = "hm-bak";
              home-manager.extraSpecialArgs = { inherit inputs hostname; username = hostname; };

              home-manager.users.${hostname} = import ./modules/home-manager/home.nix;
            }
          ];
        };
    in
    {
      nixosConfigurations = {
        surface = mkHost "surface";
        thinkpad = mkHost "thinkpad";
      };

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
    };
}
