{ ... }: {
    # Sound settings
    security.rtkit.enable = true;
    services.pulseaudio.enable = false;
    # CLI is wpctl (wireplumber) + pipewire's pulse shim — no full pulseaudio pkg needed
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };
}
