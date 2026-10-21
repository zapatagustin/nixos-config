{ config, lib, ... }:
let
  cfg = config.services.searxng-podman;
in
{
  # Not services.searx: that name is nixpkgs' native module.
  options.services.searxng-podman.enable = lib.mkEnableOption "SearXNG metasearch engine (Podman container)";

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers = {
      backend = "podman";
      containers.searxng = {
        image = "docker.io/searxng/searxng:latest";
        ports = map (addr: "${addr}:8888:8080") config.myContainers.publishAddresses;
        # settings.yml (incl. server.secret_key) lives here, outside git.
        volumes = [ "/var/lib/searxng:/etc/searxng:rw" ];
        environment.SEARXNG_BASE_URL = "http://${config.networking.hostName}.taild4c79d.ts.net:8888/";
        extraOptions = [
          "--cap-drop=ALL"
          "--cap-add=CHOWN"
          "--cap-add=SETGID"
          "--cap-add=SETUID"
        ];
      };
    };
    systemd.tmpfiles.rules = [ "d /var/lib/searxng 0750 root root - -" ];
  };
}
