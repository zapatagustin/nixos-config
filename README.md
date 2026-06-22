# nixos-config

Single-host NixOS flake for a ThinkPad (`thinkpad`). CachyOS kernel, Home Manager
as a NixOS module, no desktop environment (console only), gruvbox via Stylix.

## Build

```sh
sudo nixos-rebuild switch --flake /home/thinkpad/nixos-config#thinkpad
# or, with nh (NH_FLAKE is set):
nh os switch
```

## Secrets (sops-nix)

Secrets are encrypted with **age** and committed to the repo encrypted. The
thinkpad decrypts them at boot using its **SSH host key** (no extra key to
manage). A personal age key lets you edit secrets.

The sops module is wired but **disabled until the encrypted file exists** — the
import in `modules/modules.nix` is commented out so the flake still evaluates.

### One-time setup (run on the thinkpad)

```sh
# 0. tooling
nix shell nixpkgs#ssh-to-age nixpkgs#age nixpkgs#sops

# 1. host recipient (from the SSH host key)
ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
#   -> prints age1... (HOST key)

# 2. personal recipient (to edit secrets yourself)
age-keygen -o ~/.config/sops/age/keys.txt
#   -> prints "Public key: age1..." (PERSONAL key). Back up keys.txt safely.

# 3. paste both age keys into .sops.yaml, replacing the PLACEHOLDER lines
#    (host_thinkpad = HOST key, user_agustin = PERSONAL key)

# 4. create + encrypt the secrets file
sops secrets/secrets.yaml
#    editor opens — add:
#        tailscale:
#            authkey: tskey-auth-xxxxxxalkjf...
#    sops saves it ENCRYPTED. Get the authkey from:
#      - Tailscale SaaS: login.tailscale.com -> Settings -> Keys -> Auth keys, OR
#      - Headscale:      headscale preauthkeys create

# 5. enable the module: uncomment ./secrets/sops.nix in modules/modules.nix

# 6. rebuild
sudo nixos-rebuild switch --flake .#thinkpad
```

After this, `secrets/secrets.yaml` (encrypted) is safe to commit and push.

### Editing secrets later

```sh
sops secrets/secrets.yaml      # decrypts in-memory, re-encrypts on save
```

### Adding a new secret

1. Add a key under `secrets/secrets.yaml` (via `sops`).
2. Declare it: `sops.secrets."path/name" = {};` in `modules/secrets/sops.nix`.
3. Reference its path: `config.sops.secrets."path/name".path`.

## Layout

See `CLAUDE.md` for the module import tree and conventions. Design specs for
larger changes live in `docs/superpowers/specs/`.
