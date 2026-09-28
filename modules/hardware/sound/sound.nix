_: {
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
    # No sink priority rules: stock wireplumber already ranks USB sinks
    # (dock 3.5mm jack, USB-C dongle: 1109) above the built-in card (1009).
    # A sink picked by hand with `wpctl set-default` is remembered in
    # ~/.local/state/wireplumber/default-nodes and overrides that ranking.
  };
}
