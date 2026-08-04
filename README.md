# nixos-config

Multi-host NixOS flake: `surface` (work laptop, docks to two Samsung LF27T35) and
`thinkpad` (nomad, never docks). Per host, the user name and the host name are the
same. CachyOS kernel, Home Manager as a NixOS module, Hyprland under uwsm with a
custom quickshell bar (no desktop environment), gruvbox via Stylix.

## Build

```sh
sudo nixos-rebuild switch --flake .#surface     # or .#thinkpad
nh os switch                                     # NH_FLAKE is set per host, no path needed
nh os boot                                       # activate on next boot only
```

`NH_FLAKE` comes from `flakePath`, which is `~/personal/nixos-config` on surface and
`~/nixos-config` everywhere else — so `nh` works from any directory.

## Checks

```sh
nix flake check   # eval both hosts + every gate
nix fmt           # nixpkgs-fmt, the flake formatter
```

There are no unit tests; `nix flake check` plus a build is the validation. It gates
the generated Hyprland Lua (via the real `--verify-config`), the quickshell QML, the
source linters, and `scripts/repo-lint.sh`, whose rules exist because this repo
already shipped each of those bugs with a green check. See CLAUDE.md for the list.

Optional, once per clone — the same source checks on staged files, in milliseconds:

```sh
git config core.hooksPath scripts/hooks
```

## Secrets (sops-nix)

Active. Secrets live encrypted in `modules/secrets/secrets.yaml` and are committed
that way. Each host decrypts at boot with its own **SSH host key**
(`sops.age.sshKeyPaths`), so there is no extra key to deploy. Decrypted values
appear under `/run/secrets/`.

`.sops.yaml` lists the recipients: both hosts' host keys, plus a personal age key at
`~/.config/sops/age/keys.txt` so that secrets can be edited by hand from surface.

### Editing

```sh
sops modules/secrets/secrets.yaml            # decrypts in memory, re-encrypts on save
sops unset modules/secrets/secrets.yaml '["key"]'   # remove a key
sops -d modules/secrets/secrets.yaml >/dev/null     # verify it still decrypts
```

**Never edit that file with a text editor.** It carries a MAC over the whole
document, so a hand edit breaks decryption at activation and takes every secret in
it down at once. The `sops` and `age` CLIs are installed via
`modules/home-manager/dev`.

### Adding a secret

1. `sops modules/secrets/secrets.yaml` and add the key.
2. Declare it: `sops.secrets."path/name" = { };` in `modules/secrets/sops.nix`.
3. Read it from `/run/secrets/path/name`, or reference
   `config.sops.secrets."path/name".path`.

### Enrolling a new host

```sh
ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub   # run ON the new host
```

Add the resulting `age1...` to `keys:` and to the `creation_rules` key group in
`.sops.yaml`, then re-encrypt for the new recipient list:

```sh
sops updatekeys modules/secrets/secrets.yaml
```

## Layout

`CLAUDE.md` has the module import tree and the conventions. Design docs for larger
changes live in `docs/superpowers/specs/`. `docs/config-review.md` is a dated
snapshot of one audit, not a description of the current config.
