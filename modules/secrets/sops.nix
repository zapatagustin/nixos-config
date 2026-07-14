{ config, ... }:
{
  # Encrypted secrets file, safe to commit (see README "Secrets" section).
  sops.defaultSopsFile = ./secrets.yaml;

  # Host decrypts at activation using its own SSH host key (derived to age).
  # No extra key to manage; the key already exists and persists.
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # Decrypted to /run/secrets/tailscale/authkey (root, 0400).
  sops.secrets."tailscale/authkey" = { };

  # Tailscale auto-joins the tailnet using the decrypted key, no manual login.
  services.tailscale.authKeyFile = config.sops.secrets."tailscale/authkey".path;
}
