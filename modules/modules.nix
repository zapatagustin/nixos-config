{ ... }:
{
  imports = [
    ./boot/boot.nix
    ./init/init.nix
    ./themes/kanagawa.nix
    ./hardware/hardware.nix
    ./gaming/gaming.nix
  ];
}
