# herdr-nav <left|down|up|right> <chord>
#
# A direct chord in herdr is taken from every pane, so Alt+d/h/t/n would never
# reach neovim. This hands the chord back to neovim when it is the focused
# pane's foreground process, and moves herdr focus otherwise.
#
# Fail open: any doubt (herdr unreachable, unexpected JSON, focus error) sends
# the chord to the pane. A key that does something odd beats a key that is lost.
# This is why the script does not run with `set -e`.
dir=${1:?usage: herdr-nav <left|down|up|right> <chord>}
chord=${2:?usage: herdr-nav <left|down|up|right> <chord>}
bin=${HERDR_BIN_PATH:-herdr}
pane=${HERDR_ACTIVE_PANE_ID:-}

# Nothing to move or to send to without an active pane.
[ -n "$pane" ] || exit 0

# Every herdr call is bounded: a hung herdr socket must not swallow the key.
# Two bounded calls on the fail-open path stay under two seconds.
h() { timeout 0.8 "$bin" "$@"; }

send() {
  h pane send-keys "$pane" "$chord" >/dev/null
}

names=$(h pane process-info --pane "$pane" 2>/dev/null |
  jq -er '.result.process_info.foreground_processes | map(.name) | join(" ")') || {
  send
  exit
}

# Any name containing nvim counts (nvim, .nvim-wrapped, a renamed wrapper).
# ecomono: neovim running inside ssh or another shell in the pane shows up as
# ssh/the shell, so it is not seen and the chord moves herdr focus instead.
# Upgrade: have neovim report itself (an escape sequence or a herdr agent
# report) and read that here.
case $names in
*nvim*) send ;;
*) h pane focus --direction "$dir" --pane "$pane" >/dev/null || send ;;
esac
