# herdr-dev [SPEC] [-w BRANCH]
#
# SPEC: any combination of v (neovim), c (Claude Code), o (omp); default vco.
# Opens a tab named after the working directory and fills it. With -w, first
# creates a git worktree for BRANCH next to the main worktree (named after it)
# and works there.
bin=${HERDR_BIN_PATH:-herdr}
claude_cmd=${HERDR_DEV_CLAUDE_CMD:-claude --dangerously-skip-permissions}
omp_cmd=${HERDR_DEV_OMP_CMD:-omp}
usage='usage: herdr-dev [SPEC] [-w BRANCH]   SPEC = letters v c o (default vco)'

die() {
  echo "herdr-dev: $*" >&2
  exit 1
}

if [ -z "${HERDR_ENV:-}" ]; then
  echo "herdr-dev: must run inside herdr" >&2
  exit 2
fi

spec=vco
branch=
while [ $# -gt 0 ]; do
  case $1 in
  -w) branch=${2:?$usage}; shift 2 ;;
  -*) echo "$usage" >&2; exit 2 ;;
  *) spec=$1; shift ;;
  esac
done
if ! [[ $spec =~ ^[vco]+$ ]]; then
  echo "herdr-dev: bad SPEC '$spec'. $usage" >&2
  exit 2
fi
has() { [[ $spec == *"$1"* ]]; }

dir=$PWD
if [ -n "$branch" ]; then
  git rev-parse --git-dir >/dev/null 2>&1 || die "not inside a git repository"
  git check-ref-format --branch "$branch" >/dev/null 2>&1 || die "invalid branch name: $branch"
  # The first entry of the worktree list is always the main worktree, so the
  # sibling is named after it even from a subdirectory or a linked worktree.
  read -r _ main < <(git worktree list --porcelain)
  safe=${branch//[^A-Za-z0-9._-]/-}
  dir="$(dirname "$main")/$(basename "$main")-$safe"
  [ ! -e "$dir" ] || die "target already exists: $dir"
  # One line on failure (for example the branch is checked out in another
  # worktree); git's own reason is folded into it.
  add=(git worktree add)
  git show-ref --verify --quiet "refs/heads/$branch" && add+=("$dir" "$branch") || add+=(-b "$branch" "$dir")
  if ! err=$("${add[@]}" 2>&1); then
    die "cannot create worktree for branch $branch at $dir: $(tail -n 1 <<<"$err")"
  fi
  echo "$err" >&2
fi

create=("$bin" tab create --label "$(basename "$dir")" --cwd "$dir")
[ -z "${HERDR_WORKSPACE_ID:-}" ] || create+=(--workspace "$HERDR_WORKSPACE_ID")
out=$("${create[@]}") || die "tab create failed"
tab=$(jq -er '.result.tab.tab_id' <<<"$out") || die "tab create returned no tab id"
root=$(jq -er '.result.root_pane.pane_id' <<<"$out") || {
  "$bin" tab close "$tab" >/dev/null 2>&1
  die "tab create returned no root pane"
}

# A step failed after the tab exists: close it so no half-made tab stays. A
# worktree is never removed here (it may hold work), only named.
abort() {
  "$bin" tab close "$tab" >/dev/null 2>&1
  die "$1; tab closed${branch:+, worktree kept at $dir}"
}
# HERDR_DEV_TEST_FAIL is test-only: it makes this step fail on demand.
"$bin" tab focus "$tab" >/dev/null && [ -z "${HERDR_DEV_TEST_FAIL:-}" ] || abort "tab focus failed"

agents=()
has c && agents+=("$claude_cmd")
has o && agents+=("$omp_cmd")

if has v; then
  # neovim opens the agents itself (ClaudeCode / OmpPane are defined in the
  # neovim config) so they are paired to this editor.
  nvim_cmd="exec nvim"
  has c && nvim_cmd+=" -c ClaudeCode"
  has o && nvim_cmd+=" -c OmpPane"
  "$bin" pane run "$root" "$nvim_cmd" >/dev/null || abort "starting neovim failed"
else
  "$bin" pane run "$root" "exec ${agents[0]}" >/dev/null || abort "starting ${agents[0]} failed"
  if [ "${#agents[@]}" -gt 1 ]; then
    # sh -c lets the agent command string keep its own arguments.
    herdr-pane --tab "$tab" --cwd "$dir" --width 50 -- sh -c "exec ${agents[1]}" >/dev/null ||
      abort "opening the second agent pane failed"
  fi
fi
echo "$tab"
