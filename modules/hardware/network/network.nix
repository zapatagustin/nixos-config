{ ... }: {
  networking.networkmanager = {
    enable = true;
    wifi.backend = "iwd";
  };

  services.resolved.enable = true;
  services.vnstat.enable = true;
}
