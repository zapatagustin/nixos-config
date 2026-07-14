{ pkgs, ... }: {
  imports = [
    ./pihole.nix
  ];

  virtualisation.podman = {
    enable = true;
    dockerCompat = true; # alias docker -> podman
    defaultNetwork.settings.dns_enabled = true;
    autoPrune.enable = true;
  };

  environment.systemPackages = with pkgs; [
    podman-compose
    distrobox
    dnsutils # dig/nslookup for DNS diagnostics (Pi-hole etc.)
  ];
}
