{ config, username, ... }:
{
  # Encrypted secrets file, safe to commit (see README "Secrets" section).
  sops.defaultSopsFile = ./secrets.yaml;

  # Host decrypts at activation using its own SSH host key (derived to age).
  # No extra key to manage; the key already exists and persists.
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # opencode provider API keys. Decrypted to /run/secrets/opencode/<name>, owned
  # by the host user so opencode (a user process) can read them via {file:...}.
  sops.secrets."opencode/nvidia-api-key".owner = username;
  sops.secrets."opencode/groq-api-key".owner = username;
  sops.secrets."opencode/cerebras-api-key".owner = username;
  sops.secrets."opencode/openrouter-api-key".owner = username;

  # Anthropic API key for Zed (read by the wrapped zeditor at launch).
  sops.secrets."zed/anthropic-api-key".owner = username;

  # Hermes Agent API keys (OPENROUTER_API_KEY, ANTHROPIC_API_KEY, etc.).
  # Decrypted to /run/secrets/hermes/env — systemd reads it as root before
  # dropping to the hermes user. Fill in with `sops modules/secrets/secrets.yaml`.
  # disabled until modules/ai/hermes.nix is re-enabled (see modules/modules.nix) —
  # the hermes-agent flake input is broken, so nothing reads this secret right now.
  # sops.secrets."hermes/env" = { };

  # disabled until a tailscale authkey is added to secrets.yaml
  # sops.secrets."tailscale/authkey" = { };
  # services.tailscale.authKeyFile = config.sops.secrets."tailscale/authkey".path;
}
