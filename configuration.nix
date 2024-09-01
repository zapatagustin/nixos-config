{ lib, config, pkgs, ... }:
let
  # These variable names are used by Aegis backend
  version = "unstable"; #or 24.05
  username = "thinkpad";
  hashed = "$6$zjvJDfGSC93t8SIW$AHhNB.vDDPMoiZEG3Mv6UYvgUY6eya2UY5E2XA1lF7mOg6nHXUaaBmJYAMMQhvQcA54HJSLdkJ/zdy8UKX3xL1";
  hashedRoot = "$6$zjvJDfGSC93t8SIW$AHhNB.vDDPMoiZEG3Mv6UYvgUY6eya2UY5E2XA1lF7mOg6nHXUaaBmJYAMMQhvQcA54HJSLdkJ/zdy8UKX3xL1";
  hostname = "thinkpad-t480s";
  desktop = "kde";
  dmanager = "sddm";
  mainShell = "zsh";
  terminal = "kitty";
  browser = "floorp";
  bootloader = "systemd";
  hm-version = if version == "unstable" then "master" else "release-"version; # "master" or "release-24.05"; # Correspond to home-manager GitHub branches
  #home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/${hm-version}.tar.gz";
in
{
  imports = [ # Include the results of the hardware scan.
    {
      thinkpad = {
        inherit bootloader terminal mainShell browser;
        enable = true;
        homeManagerUser = username;
        baseConfiguration = true;
        baseSoftware = true;
        baseLocale = true;
        desktopManager = desktop;
        displayManager = dmanager;
      };
    }
    #(import "${home-manager}/.")
    /etc/nixos/hardware-configuration.nix
    ./.
  ];

  users = lib.mkIf config.thinkpad.enable {
    mutableUsers = false;
    extraUsers.root.hashedPassword = "${hashedRoot}";
    users.${config.thinkpad.homeManagerUser} = {
      shell = pkgs.${config.thinkpad.mainShell};
      isNormalUser = true;
      hashedPassword = "${hashed}";
      extraGroups = [ "wheel" "input" "video" "render" "networkmanager" ];
    };
  };

  networking = {
    hostName = "${hostname}";
    enableIPv6 = false;
  };

  services.flatpak.enable = true;

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    openFirewall = true;
  };
}
