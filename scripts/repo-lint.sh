#!/usr/bin/env bash
# Repo-specific structural checks that no off-the-shelf linter covers.
#
# Each one exists because this repo already shipped the exact bug it catches, and
# `nix flake check` stayed green through every one of them:
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

# Is $1 referenced as a path by any .nix file other than $2?
#
# Comments are stripped first and the needle must be preceded by a slash. Both
# matter: an earlier version grepped raw file content for the bare name, so a
# passing MENTION in prose satisfied it. Demonstrated live — deleting the only
# real import of shells/starship/starship.nix still reported ok, because
# modules/home-manager/stylix.nix has a comment containing "starship.nix".
#
# Stripping at `#` can also blank a real reference that sits after a `#` on the
# same line. That direction is deliberate: it can only produce a false POSITIVE
# (a used file reported as orphaned), which is loud and immediately fixable,
# never a silent miss.
referenced_as_path() {
  local needle=$1 self=$2 cand
  while read -r cand; do
    [ "$cand" = "$self" ] && continue
    # Redirect, NOT `sed ... | grep -q`. Under `set -o pipefail` that pipeline is a
    # race: grep -q exits at the first match and sed, still writing, takes SIGPIPE
    # (141), which pipefail then makes the pipeline's status — so a real match
    # intermittently reads as "not referenced". It made rule 1 flake on
    # modules/home-manager/home.nix (matched at flake.nix:97, ~100 lines from EOF)
    # roughly 2 runs in 5. A process substitution keeps grep the only command whose
    # status counts. Same fix in rule 4 below.
    if grep -qF -- "/$needle" < <(sed 's/#.*//' "$cand"); then return 0; fi
  done < <(nix_files)
  return 1
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
  referenced_as_path "$needle" "$f" ||
    note "orphan: $f is not imported by any .nix file (dead file, or you forgot to wire it)"
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

# ── 4. No `preload: false` on a FileView in the quickshell bar ──────────────────
#
# In quickshell 0.3.0, FileView.reload() does NOT start a FIRST read when preload
# is off: Quickshell/Io/FileView.qml's onPathChanged leaves __preload false, so
# assigning `path` arms nothing and the following reload() fires neither onLoaded
# nor onLoadFailed. Brightness.qml shipped that way and showed "--" forever with
# NOTHING in the log, because no read was ever attempted.
#
# This is a static proxy for a runtime semantic, and deliberately so: exercising
# the real behaviour needs a running quickshell, which needs a Wayland display,
# which the Nix build sandbox does not have. qmllint cannot see it either -- it is
# not a type error, and the qmllint gate passes on the broken version. So the
# pattern is banned by grep instead. If a FileView ever genuinely needs preload
# off, it must not depend on reload() for its first read, and this rule needs the
# exception spelled out here.
#
# `//` comments are stripped first so the warning comments in Brightness.qml that
# name the pattern do not trip the rule that exists because of them.
bar="$hypr/quickshell/bar"
while read -r qml; do
  # Redirect rather than pipe, for the pipefail/SIGPIPE reason spelled out in
  # referenced_as_path. Here the race loses a REAL finding instead of inventing a
  # false one, which is the silent direction — the whole point of this rule is that
  # nothing else catches the pattern.
  if grep -qE 'preload[[:space:]]*:[[:space:]]*false' < <(sed 's|//.*||' "$qml"); then
    note "preload: false in $qml — reload() will not perform the FIRST read (quickshell 0.3.0); see rule 4 in $0"
  fi
done < <(find "$bar" -name '*.qml' 2>/dev/null | sort)

# ── 5. No display-connector literals in shared home-manager modules ─────────────
#
# Same reasoning as rule 3, one level deeper: `HDMI-A-1` is not a host name, but it
# is still one host's hardware, and modules/home-manager/** is evaluated for both.
# A hardcoded `HDMI-A-1` monitor line plus tv-scale.sh sat here for three weeks, so
# surface's TV port was baked into thinkpad's config too -- invisible only because
# that port happens not to exist there. It was dead config in the end (no TV was
# ever attached) and got deleted, but the shape of the mistake is what this catches.
#
# The working pattern is the one setup-monitors.sh and monitors-detect.sh use:
# discover outputs at runtime from the EDID, never name a port. Anything that truly
# cannot be discovered belongs in an option (modules/home-manager/options.nix), set
# per host under hosts/<host>/ -- the way internalScale already works.
#
# eDP-N is deliberately allowed: every laptop has exactly one built-in panel on it,
# so it is a platform convention rather than host data. The `[^A-Za-z]` guard is
# what keeps `eDP-1` from matching the `DP-N` alternative.
#
# Comments are NOT stripped, unlike rule 4: a connector named in prose inside a
# shared module is documentation that drifts the moment the code moves, and this
# rule's own explanation lives here in scripts/, where it cannot trip itself.
hits=$(grep -rnE '(^|[^A-Za-z])(HDMI-A|DP|DVI-[DI]|VGA)-[0-9]+' \
  --include='*.nix' --include='*.sh' --include='*.qml' modules/home-manager 2>/dev/null || true)
if [ -n "$hits" ]; then
  while read -r line; do
    note "display connector literal in a shared HM module: $line"
  done <<<"$hits"
fi

if [ "$fails" -gt 0 ]; then
  echo "repo-lint: $fails finding(s)" >&2
  exit 1
fi
echo "repo-lint: ok"
