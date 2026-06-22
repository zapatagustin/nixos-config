# sops-nix secrets — Design

**Date:** 2026-06-22
**Status:** Scaffolding implemented; secret value + activation pending on thinkpad

## Goal

Declarative secrets management, fully local (no server, no cost). First secret:
Tailscale auth key, wired to `services.tailscale.authKeyFile`.

## Decisions

- Backend: **age**.
- Host decryption key: derived from the host **SSH ed25519 key** (`ssh-to-age`) —
  no new key to manage.
- First secret: **tailscale/authkey** (origin — SaaS vs Headscale — decided later;
  the sops setup is identical either way).

## Wiring

- `flake.nix`: input `sops-nix` (follows nixpkgs) + `inputs.sops-nix.nixosModules.sops`.
- `modules/secrets/sops.nix`: `defaultSopsFile`, `age.sshKeyPaths`, the secret, and
  the `services.tailscale.authKeyFile` consumer — all in one module so enabling is
  atomic.
- `.sops.yaml`: creation rules + age recipients (host + personal), placeholders
  until filled on the thinkpad.

## Bootstrap constraint

The encrypted `secrets/secrets.yaml` can only be created where the age keys exist
(the thinkpad). It cannot be produced from the dev machine. Therefore:

- The module import in `modules/modules.nix` is **commented out** so the flake
  evaluates without the file (the repo stays green).
- The full runbook (get recipients → fill `.sops.yaml` → `sops secrets/secrets.yaml`
  → uncomment import → rebuild) is documented in `README.md`.

## Verification (on thinkpad)

After the runbook + rebuild: `tailscale status` shows the node joined the tailnet
without interactive login; `/run/secrets/tailscale/authkey` exists (root, 0400).
