{ config, lib, pkgs, ... }:
let
  cfg = config.services.jellyfin-podman;
in
{
  # Not services.jellyfin: that name is nixpkgs' native module.
  options.services.jellyfin-podman.enable = lib.mkEnableOption "Jellyfin media server (Podman container)";

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers = {
      backend = "podman";
      containers.jellyfin = {
        image = "docker.io/jellyfin/jellyfin:10.11.11";
        ports = map (addr: "${addr}:8096:8096") config.myContainers.publishAddresses;
        volumes = [
          "/mnt/datos/jellyfin/config:/config:rw"
          "/mnt/datos/jellyfin/cache:/cache:rw"
          "/mnt/datos/Videos:/media/videos:ro"
          "/mnt/datos/Torrents/series:/media/series:ro"
          "/etc/localtime:/etc/localtime:ro"
        ];
        devices = [ "/dev/dri/renderD128" ]; # VA-API transcoding
        environment.TZ = config.time.timeZone;
      };
    };
    # Background priority, as the quadlet had: never starve a game.
    # /mnt/datos is nofail: not RequiresMountsFor, a failed mount would fail this unit
    # as a dependency and the restart loop would not retry. Order after the mount and
    # fail the start instead, so a missing bind source is retried every 10s.
    systemd.services.podman-jellyfin = {
      after = [ "mnt-datos.mount" ];
      wants = [ "mnt-datos.mount" ];
      serviceConfig = {
        CPUWeight = 20;
        ExecStartPre = [ "${pkgs.util-linux}/bin/mountpoint -q /mnt/datos" ];
      };
    };
  };
}
