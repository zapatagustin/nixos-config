{ ... }:
{
  imports = [
    /etc/nixos/hardware-configuration.nix
    ./default.nix
  ];

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.thinkpad = {
    isNormalUser = true;
    description = "thinkpad";
    extraGroups = [ "networkmanager" "wheel" "docker" "audio" ];
    #packages = with pkgs; [
    #  firefox
    #  kate
    #  thunderbird
    #];
  };
}
