{ config, ... }:
let
  # Every peer sharing the vault; attr name = syncthing device name. The kdbx
  # lives on the desktop (CachyOS, github:zapatagustin/cachy-config — syncthing
  # set up imperatively there); flake hosts and eventually the phone replicate
  # it. Connections ride Tailscale or LAN, with global discovery/relays as
  # fallback — the payload is an encrypted kdbx either way.
  peers = {
    desktop = {
      id = "KVPGLUL-2F77P3A-MK7EWXQ-7ELAK34-XQY72CC-Z2UDK6G-ZZJXTBE-Q3QECA6";
      # Static Tailscale address first so laptops dial the desktop directly
      # from any network; "dynamic" keeps LAN/global discovery as fallback.
      addresses = [ "tcp://desktop.taild4c79d.ts.net:22000" "dynamic" ];
    };
    surface.id = "NAFA6A4-P7AYF6X-VQUK5VR-QI2ZF4M-RSIAK7G-IDN4GOQ-LESJ3AL-G5PPSQY";
    thinkpad.id = "3LTAYOR-335PKVS-OUNWH6M-TLBEIAX-VYL577K-YA6SNRB-ERXBOAV-ESDHZAD";
  };
in
{
  services.syncthing = {
    enable = true;
    settings = {
      devices = peers;
      folders.vault = {
        path = "${config.home.homeDirectory}/vault";
        devices = builtins.attrNames peers;
      };
      options.urAccepted = -1;
    };
  };
}
