{
  description = "flakes";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    stylix.url = "github:danth/stylix";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, stylix, ... }: {
    nixosConfigurations = {
      thinkpad = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
          stylix.nixosModules.stylix
          home-manager.nixosModules.home-manager
          {
            home-manager.useUserPackages = true;
            home-manager.users.thinkpad = import ./modules/home-manager/home.nix;
          }
        ];
      };
    };

    #homeConfigurations.thinkpad = home-manager.lib.homeManagerConfiguration {
    #  pkgs = nixpkgs.legacyPackages.x86_64-linux;
    #  home-manager.useGlobalPkgs = true;
    #  home-manager.useUserPackages = true;
    #  modules = [
    #    ./modules/home-manager/home.nix
    #    stylix.homeManagerModules.stylix
    #  ];
    #};
  };
}
