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

      # Auto-route audio to the Apple USB-C dongle whenever it's present (dock
      # connected). Bump its session priority above the built-in card so
      # wireplumber's default-node policy picks it on connect and falls back to
      # built-in on unplug. Matched by node.name prefix (serial-independent).
      wireplumber.extraConfig."51-apple-usbc-default" = {
        "monitor.alsa.rules" = [
          {
            matches = [{ "node.name" = "~alsa_output.usb-Apple.*"; }];
            actions.update-props = {
              "priority.session" = 2000;
              "priority.driver" = 2000;
            };
          }
        ];
      };
    };
}
