# herdr-pane [--env K=V]... [--cwd DIR] [--tab ID] [--width PCT] [-- COMMAND...]
#
# Adds one pane to a tab and prints its id. One-pane tab: new pane on the right
# with PCT% of the width (default 40). Otherwise: below the lowest pane of the
# rightmost column, splitting it in half, so columns grow downward instead of
# producing ever narrower panes.
bin=${HERDR_BIN_PATH:-herdr}
tab=${HERDR_ACTIVE_TAB_ID:-${HERDR_TAB_ID:-}}
cwd=${HERDR_ACTIVE_PANE_CWD:-$PWD}
width=40
envs=()

die() {
  echo "herdr-pane: $*" >&2
  exit 1
}

while [ $# -gt 0 ]; do
  case $1 in
  --env) envs+=(--env "${2:?--env needs K=V}"); shift 2 ;;
  --cwd) cwd=${2:?--cwd needs a directory}; shift 2 ;;
  --tab) tab=${2:?--tab needs an id}; shift 2 ;;
  --width) width=${2:?--width needs a percentage}; shift 2 ;;
  --) shift; break ;;
  *) die "unknown argument: $1" ;;
  esac
done

[ -n "$tab" ] || die "no tab: run it from herdr or pass --tab"
case $width in
[1-9] | [1-9][0-9]) ;;
*) die "--width must be 1..99" ;;
esac

layout=$("$bin" api snapshot | jq -c --arg t "$tab" \
  '.result.snapshot.layouts[] | select(.tab_id == $t)') || die "cannot read herdr state"
[ -n "$layout" ] || die "tab $tab not found"

# Target = lowest pane among those with the greatest x (the rightmost column).
target=$(jq -r '[.panes[] | {id: .pane_id, x: .rect.x, y: .rect.y}]
  | (map(.x) | max) as $mx | map(select(.x == $mx)) | max_by(.y) | .id' <<<"$layout")

# --ratio is the share the EXISTING pane keeps, so the new pane's share is 1-ratio.
if [ "$(jq '.panes | length' <<<"$layout")" -eq 1 ]; then
  direction=right
  ratio=$(printf '0.%02d' $((100 - width)))
else
  direction=down
  ratio=0.5
fi

new=$("$bin" pane split "$target" --direction "$direction" --ratio "$ratio" \
  --cwd "$cwd" "${envs[@]}" --no-focus | jq -er '.result.pane.pane_id') ||
  die "split failed"

if [ $# -gt 0 ]; then
  # ecomono: %q quoting assumes a bash/zsh-compatible pane shell (fish lacks
  # $'..'). Upgrade: write the command to a temp script and exec that.
  # exec makes the pane close when the command exits.
  "$bin" pane run "$new" "exec $(printf '%q ' "$@")" >/dev/null || die "run failed"
fi
echo "$new"
