#!/usr/bin/env bash
# Repo-specific structural checks that no off-the-shelf linter covers.
#
# All three exist because this repo already shipped the exact bug each one catches,
# and `nix flake check` stayed green through every one of them:
#   1. modules/theme/generic-dm-stub.nix sat unimported for weeks. The import-tree
#      convention has no lint, so an orphaned file is invisible.
#   2. quickshell's bar called ~/.config/hypr/set-theme.sh, which did not exist. The
#      Process swallowed the error, so the button silently did nothing.
#   3. shells/zsh/zsh.nix hardcoded `#surface` in a module evaluated for BOTH hosts,
#      so `nixos-install` on thinkpad rebuilt the wrong machine.
#
# Run from the repo root. Exits 1 on the first category with findings.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
fails=0
note() {
  echo "repo-lint: $*" >&2
  fails=$((fails + 1))
}

nix_files() { find . -name '*.nix' -not -path './.git/*' | sort; }

# ── 1. Every .nix must be reachable from some `imports` ──────────────────────────
#
# These are roots or are imported through a computed path (flake.nix builds
# ./hosts/${hostname}/default.nix and configuration.nix does (./hosts + "/...")),
# so a literal grep cannot see them. Anything NOT on this list must be named
# somewhere.
is_root() {
  case "$1" in
    ./flake.nix | ./default.nix | ./configuration.nix) return 0 ;;
    ./hosts/*/default.nix | ./hosts/*/hardware-configuration.nix) return 0 ;;
    *) return 1 ;;
  esac
}

while read -r f; do
  is_root "$f" && continue
  base=$(basename "$f")
  if [ "$base" = default.nix ]; then
    # Imported as its containing directory, e.g. `imports = [ ./editors/emacs ];`
    needle=$(basename "$(dirname "$f")")
  else
    needle="$base"
  fi
  # Any other .nix naming it? --fixed-strings: these are paths, not patterns.
  if ! grep -rlF --include='*.nix' -- "$needle" . 2>/dev/null |
    grep -qv "^${f}$"; then
    note "orphan: $f is not named in any imports list (dead file, or you forgot to wire it)"
  fi
done < <(nix_files)

# ── 2. Every ~/.config/hypr/*.sh referenced must exist AND be deployed ───────────
hypr=modules/home-manager/wm/hyprland
refs=$(grep -rhoE '\.config/hypr/[A-Za-z0-9_-]+\.sh' \
  --include='*.qml' --include='*.sh' --include='*.nix' "$hypr" 2>/dev/null |
  sed 's|.*/||' | sort -u)

for s in $refs; do
  [ -f "$hypr/scripts/$s" ] ||
    note "dangling: something references ~/.config/hypr/$s but $hypr/scripts/$s does not exist"
  grep -qF "\"hypr/$s\"" "$hypr/default.nix" ||
    note "undeployed: $s is referenced but has no xdg.configFile entry, so it is never installed"
done

# ── 3. No host name literals in shared home-manager modules ─────────────────────
#
# modules/home-manager/** is evaluated identically for surface and thinkpad, so a
# literal host name there is a latent cross-host bug. `hostname`, `username` and
# `flakePath` all arrive via extraSpecialArgs -- use those.
hits=$(grep -rnE '"(surface|thinkpad)"' --include='*.nix' modules/home-manager 2>/dev/null || true)
if [ -n "$hits" ]; then
  while read -r line; do
    note "host literal in a shared HM module: $line"
  done <<<"$hits"
fi

if [ "$fails" -gt 0 ]; then
  echo "repo-lint: $fails finding(s)" >&2
  exit 1
fi
echo "repo-lint: ok"
