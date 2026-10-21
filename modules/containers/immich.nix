{ config, lib, ... }:
let
  cfg = config.services.immich-podman;
in
{
  # Not services.immich: that name is nixpkgs' native module. Kept as containers so
  # the existing Postgres volume (VectorChord build pinned below) is reused as-is.
  options.services.immich-podman.enable = lib.mkEnableOption "Immich photo server (Podman containers)";

  config = lib.mkIf cfg.enable (
    let
      podman = "${config.virtualisation.podman.package}/bin/podman";
      network = "immich";
      version = "v3.1.0";
      names = [ "immich-server" "immich-machine-learning" "immich-postgres" "immich-redis" ];
      # dotenv from sops (secrets.yaml key immich/db-env) with POSTGRES_USER,
      # POSTGRES_DB, POSTGRES_PASSWORD, DB_USERNAME, DB_DATABASE_NAME, DB_PASSWORD.
      dbEnv = config.sops.secrets."immich/db-env".path;
      # Bind mount, not a named volume, so the attribute below can be set on it.
      pgdata = "/var/lib/immich/postgres";
    in
    {
      sops.secrets."immich/db-env" = { };

      # No btrfs copy-on-write for the database: Postgres rewrites pages in place,
      # which CoW turns into fragmentation. +C only takes effect on files created
      # after it is set, so it goes on the empty directory before initdb (restore
      # an existing DB from a pg_dump into it, never by copying the old files).
      # Mode/owner left as "-": the postgres entrypoint chowns it on first start
      # and tmpfiles must not reset that on every boot.
      systemd.tmpfiles.rules = [
        "d ${pgdata} - - - -"
        "h ${pgdata} - - - - +C"
      ];

      virtualisation.oci-containers = {
        backend = "podman";
        containers = {
          immich-server = {
            image = "ghcr.io/immich-app/immich-server:${version}";
            networks = [ network ];
            ports = map (addr: "${addr}:2283:2283") config.myContainers.publishAddresses;
            volumes = [
              "/mnt/datos/immich/library:/data:rw"
              "/etc/localtime:/etc/localtime:ro"
            ];
            devices = [ "/dev/dri/renderD128" ];
            environmentFiles = [ dbEnv ];
            environment = {
              DB_HOSTNAME = "immich-postgres";
              REDIS_HOSTNAME = "immich-redis";
              TZ = config.time.timeZone;
              NODE_OPTIONS = "--max-old-space-size=512";
            };
            dependsOn = [ "immich-postgres" "immich-redis" ];
          };

          immich-machine-learning = {
            image = "ghcr.io/immich-app/immich-machine-learning:${version}";
            networks = [ network ];
            volumes = [ "immich-model-cache:/cache" ];
          };

          immich-postgres = {
            image = "ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0@sha256:bcf63357191b76a916ae5eb93464d65c07511da41e3bf7a8416db519b40b1c23";
            networks = [ network ];
            volumes = [ "${pgdata}:/var/lib/postgresql/data" ];
            environmentFiles = [ dbEnv ];
            environment.POSTGRES_INITDB_ARGS = "--data-checksums";
            extraOptions = [ "--shm-size=128m" ];
          };

          immich-redis = {
            image = "docker.io/valkey/valkey:9@sha256:8e8d64b405ce18f41b8e5ee20aa4687a8ed0022d1298f2ce31cdcf3a76e09411";
            networks = [ network ];
          };
        };
      };

      # oci-containers attaches to `networks` but never creates them; the containers
      # resolve each other by name on this one, so it must exist before they start.
      systemd.services = {
        "podman-network-${network}" = {
          description = "Podman network for Immich";
          requiredBy = map (n: "podman-${n}.service") names;
          before = map (n: "podman-${n}.service") names;
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = "${podman} network exists ${network} || ${podman} network create ${network}";
        };
      } // lib.genAttrs (map (n: "podman-${n}") names) (unit: {
        # Background priority, as the quadlets had: never starve a game.
        serviceConfig.CPUWeight = 20;
        # The library lives on the nofail data disk: wait for it.
        unitConfig = lib.optionalAttrs (unit == "podman-immich-server") {
          RequiresMountsFor = [ "/mnt/datos" ];
        };
      });
    }
  );
}
