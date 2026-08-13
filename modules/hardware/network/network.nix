_: {
  networking = {
    networkmanager = {
      enable = true;
      wifi.backend = "wpa_supplicant";
    };
    nftables.enable = true; # modern firewall backend
    firewall.trustedInterfaces = [ "tailscale0" ]; # don't filter tailnet traffic
  };

  services.resolved.enable = true;
  services.vnstat.enable = true;

  # Tailscale mesh VPN
  services.tailscale = {
    enable = true;
    openFirewall = true;
    # MagicDNS: resolve *.ts.net peers (navidrome on desktop) via resolved
    extraSetFlags = [ "--accept-dns=true" ];
  };
}
