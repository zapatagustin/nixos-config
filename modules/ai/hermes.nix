# Hermes Agent — AI agent framework by Nous Research.
# Native systemd service, declarative config via NixOS module.
# Secrets managed via sops-nix (modules/secrets/sops.nix).
{ config, ... }:

let
  inherit (config.sops) secrets;
in
{
  services.hermes-agent = {
    enable = true;

    # Model default: OpenRouter. Set model.default + model.base_url to use
    # a different provider. Examples:
    #   "anthropic/claude-sonnet-4"        (OpenRouter)
    #   "claude-sonnet-4-20250514"         (Anthropic direct, with base_url)
    #   "google/gemini-3-flash"            (OpenRouter)
    settings.model.default = "openrouter/anthropic/claude-sonnet-4";

    # Provide OPENROUTER_API_KEY (or ANTHROPIC_API_KEY / whatever your
    # provider expects). The sops secret is decrypted to:
    #   /run/secrets/hermes/env
    # and systemd reads it as root before dropping to the hermes user.
    environmentFiles = [ secrets."hermes/env".path ];

    # CLI available on PATH, shares state with the systemd service.
    addToSystemPackages = true;
  };
}
