{ config, ... }:
{
  # Wifi profiles for every host, so a new machine knows the usual networks
  # after one rebuild. Secrets stay out of the nix store: NetworkManager
  # substitutes the $VARS below at profile-load time from the sops-provided
  # env file. secrets.yaml must hold a "wifi-env" key shaped like:
  #   HOME_PSK=...
  #   ELTACU_PSK=...
  #   SIEMPREBOCA_PSK=...
  #   WEWORK_PASSWORD=...
  # A rebuild with that key missing fails at sops activation, by design.
  sops.secrets."wifi-env" = { };

  networking.networkmanager.ensureProfiles = {
    environmentFiles = [ config.sops.secrets."wifi-env".path ];
    profiles = {
      home = {
        connection = {
          id = "AGUSTIN Plus";
          type = "wifi";
        };
        wifi.ssid = "AGUSTIN Plus";
        wifi-security = {
          key-mgmt = "wpa-psk";
          psk = "$HOME_PSK";
        };
      };
      eltacu = {
        connection = {
          id = "ElTacu";
          type = "wifi";
        };
        wifi.ssid = "ElTacu";
        wifi-security = {
          key-mgmt = "wpa-psk";
          psk = "$ELTACU_PSK";
        };
      };
      siempreboca = {
        connection = {
          id = "SiempreBoca";
          type = "wifi";
        };
        # The trailing space is real — it is part of the broadcast SSID.
        wifi.ssid = "SiempreBoca ";
        wifi-security = {
          key-mgmt = "wpa-psk";
          psk = "$SIEMPREBOCA_PSK";
        };
      };
      wework = {
        connection = {
          id = "weworkwifi";
          type = "wifi";
        };
        wifi.ssid = "WeWorkWiFi";
        wifi-security.key-mgmt = "wpa-eap";
        "802-1x" = {
          eap = "peap";
          identity = "agustin.zapata@atlas.red";
          phase2-auth = "mschapv2";
          password = "$WEWORK_PASSWORD";
        };
      };
    };
  };
}
