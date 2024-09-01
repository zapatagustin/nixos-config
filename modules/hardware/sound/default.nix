{ lib, pkgs, config, ... }: {
  config = lib.mkIf config.thinkpad.baseConfiguration {
    users.users.${config.thinkpad.homeManagerUser} = { extraGroups = [ "audio" ]; };

    # Sound settings
    security.rtkit.enable = true;
    hardware.pulseaudio.enable = false;
    environment.systemPackages = with pkgs; [ pulseaudio ];
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };
  };
}
