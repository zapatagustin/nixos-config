#!/usr/bin/env bash
# Runnable check for the herdr module: builds herdr, the generated config and
# the scripts from the flake, runs herdr isolated under a pseudo-terminal in a
# temporary directory, and asserts the behaviour the module promises.
# Prints "ok <name>" per assertion; exits non-zero on the first failure.
#
# Needs on PATH: nix, git, jq, python3. Never touches the real herdr or HOME.
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
flake=$(cd "$here/../../../.." && pwd)
host="$flake#nixosConfigurations.surface"
hm="(builtins.getFlake \"path:$flake\").nixosConfigurations.surface.config.home-manager.users.surface"

# --- build what is under test ------------------------------------------------
H=$(nix build --no-link --print-out-paths "$host.pkgs.herdr")/bin/herdr
NVIM=$(nix build --no-link --print-out-paths "$host.pkgs.neovim")/bin/nvim
cfg=$(nix build --impure --no-link --print-out-paths \
  --expr "$hm.xdg.configFile.\"herdr/config.toml\".source")
# home.packages is a list; build the four scripts and locate them by name.
mapfile -t built < <(nix build --impure --no-link --print-out-paths --expr \
  "builtins.filter (p: builtins.elem p.name [\"herdr-nav\" \"herdr-pane\" \"herdr-waiting\" \"herdr-dev\"]) $hm.home.packages")
for p in "${built[@]}"; do
  case $p in
  *-herdr-nav) nav=$p/bin/herdr-nav ;;
  *-herdr-pane) pane=$p/bin/herdr-pane ;;
  *-herdr-waiting) waiting=$p/bin/herdr-waiting ;;
  *-herdr-dev) dev=$p/bin/herdr-dev ;;
  esac
done

# --- isolated herdr ------------------------------------------------------------
# Short absolute root: unix socket paths are limited to ~108 bytes.
T=$(mktemp -d /tmp/hc.XXXXXX)
mkdir -p "$T/cfg/herdr" "$T/state" "$T/data" "$T/run" "$T/work"
# Without onboarding = false herdr shows a first-run screen that eats key presses.
# The module sets it itself; adding it again would be a duplicate TOML key.
grep -qx 'onboarding = false' "$cfg" || { echo "FAIL generated config lacks onboarding = false" >&2; exit 1; }
cat "$cfg" >"$T/cfg/herdr/config.toml"
export XDG_CONFIG_HOME=$T/cfg XDG_STATE_HOME=$T/state XDG_DATA_HOME=$T/data XDG_RUNTIME_DIR=$T/run
export HERDR_SOCKET_PATH=$T/run/h.sock HERDR_CLIENT_SOCKET_PATH=$T/run/hc.sock
cd "$T"

# Feeds bytes from a fifo to a pty running herdr, so real key presses reach it.
# The fifo is opened read-write so it never reports EOF.
cat >"$T/pty.py" <<'PY'
import os, pty, select, struct, sys, fcntl, termios
fifo, cmd = sys.argv[1], sys.argv[2:]
pid, fd = pty.fork()
if pid == 0:
    os.execv(cmd[0], cmd)
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 50, 200, 0, 0))
open("pty.pid", "w").write(str(pid))
f = os.open(fifo, os.O_RDWR | os.O_NONBLOCK)
while True:
    r, _, _ = select.select([fd, f], [], [], 0.2)
    if fd in r:
        try:
            if not os.read(fd, 65536):
                break
        except OSError:
            break
    if f in r:
        d = os.read(f, 4096)
        if d:
            os.write(fd, d)
PY
mkfifo "$T/in.fifo"

py_pid=
hang_pid=
cleanup() {
  [ -z "$hang_pid" ] || kill "$hang_pid" 2>/dev/null || true
  # Only what this script started: its own server (via its own socket), the pty
  # harness and the herdr client under it.
  "$H" server stop >/dev/null 2>&1 || true
  [ -z "$py_pid" ] || kill "$py_pid" 2>/dev/null || true
  [ ! -s "$T/pty.pid" ] || kill "$(cat "$T/pty.pid")" 2>/dev/null || true
  sleep 0.5
  [ -z "${HERDR_CHECK_KEEP:-}" ] || { echo "kept $T" >&2; return 0; }
  rm -rf "$T"
}
trap cleanup EXIT

python3 -I "$T/pty.py" "$T/in.fifo" "$H" >"$T/pty.log" 2>&1 &
py_pid=$!

# Set only now: herdr refuses to start when it believes it is already inside
# a herdr pane. These mimic what a pane or key command would export.
export HERDR_BIN_PATH=$H HERDR_ENV=1 HERDR_WORKSPACE_ID=w1

# --- helpers -------------------------------------------------------------------
ok() { echo "ok $1"; }
fail() { echo "FAIL $1" >&2; exit 1; }
# until <tries> <cmd...>: retry every 0.2s.
until_() { local n=$1; shift; while [ "$n" -gt 0 ]; do "$@" && return 0; sleep 0.2; n=$((n - 1)); done; return 1; }
snap() { "$H" api snapshot | jq -c .result.snapshot; }
focused() { snap | jq -r .focused_pane_id; }
# until_ re-runs a command, so a comparison must be wrapped in a function.
focus_is() { [ "$(focused)" = "$1" ]; }
key() { printf '%b' "$1" >"$T/in.fifo"; }
# pane.focus by id exists only as a socket method; also switches tab/workspace.
focus_id() {
  python3 -I - "$HERDR_SOCKET_PATH" "$1" <<'PY' >/dev/null
import json, socket, sys
s = socket.socket(socket.AF_UNIX); s.connect(sys.argv[1])
s.sendall((json.dumps({"id": "c", "method": "pane.focus", "params": {"pane_id": sys.argv[2]}}) + "\n").encode())
b = b""
while not b.endswith(b"\n"): b += s.recv(65536)
sys.exit(1 if "error" in json.loads(b) else 0)
PY
}
# rect <pane> -> "x y width"
rect() { snap | jq -r --arg p "$1" '.layouts[].panes[] | select(.pane_id == $p) | "\(.rect.x) \(.rect.y) \(.rect.width)"'; }
pane_exists() { snap | jq -e --arg p "$1" '.panes[] | select(.pane_id == $p)' >/dev/null; }
pane_gone() { ! pane_exists "$1"; }
fg_names() { "$H" pane process-info --pane "$1" | jq -r '.result.process_info.foreground_processes | map(.name) | join(" ")'; }
has_proc() { [[ " $(fg_names "$1") " == *" $2 "* ]]; }
tab_json() { "$H" tab list | jq -c --arg t "$1" '.result.tabs[] | select(.tab_id == $t)'; }
tab_panes() { snap | jq -r --arg t "$1" '[.panes[] | select(.tab_id == $t) | .pane_id] | join(" ")'; }

until_ 50 snap >/dev/null 2>&1 || fail "herdr did not start"
p1=$(focused)
# The client swallows input for a few seconds after it starts (it waits on its
# terminal queries), so a key sent too early is lost. Type into the first pane
# until the echo comes back, which proves the input path is live.
input_live() {
  # shellcheck disable=SC2016 # the $(( )) must reach the pane shell unexpanded
  key 'echo READY$((1+1))\r'
  sleep 0.5
  "$H" pane read "$p1" 2>/dev/null | grep -q READY2
}
until_ 40 input_live || fail "herdr client never accepted input"

# --- 1. config -----------------------------------------------------------------
grep -qx 'onboarding = false' "$T/cfg/herdr/config.toml" || fail "generated config does not set onboarding = false"
ok config-sets-onboarding-off
[ "$("$H" server reload-config | jq -c .result.diagnostics)" = "[]" ] || fail "config diagnostics"
ok config-loads-without-diagnostics

# --- 2. alt+d in a shell pane moves focus left -----------------------------------
p2=$("$H" pane split "$p1" --direction right --cwd "$T" --no-focus | jq -r .result.pane.pane_id)
focus_id "$p2"
[ "$(focused)" = "$p2" ] || fail "setup focus"
key '\033d'
until_ 25 focus_is "$p1" || fail "alt+d did not move focus left"
ok alt-d-moves-focus-left-in-shell-pane

# --- 3. alt+d in nvim reaches neovim and focus stays ---------------------------
"$H" pane run "$p2" "exec $NVIM --clean -c 'nnoremap <M-d> :call writefile([\"hit\"], \"$T/marker\")<CR>'" >/dev/null
until_ 50 has_proc "$p2" nvim || fail "nvim never became the foreground process (saw: $(fg_names "$p2"))"
sleep 1 # let neovim finish its start-up before keys arrive
focus_id "$p2"
key '\033d'
until_ 25 test -s "$T/marker" || fail "neovim did not receive alt+d"
[ "$(focused)" = "$p2" ] || fail "focus moved although neovim was focused"
ok alt-d-reaches-neovim-and-focus-stays
"$H" pane close "$p2" >/dev/null

# --- 3b. a process whose name merely contains nvim still gets the chord --------------
# The wrapped nvim execs a process named exactly nvim, so link the unwrapped binary.
ln -s "$(nix build --no-link --print-out-paths "$host.pkgs.neovim-unwrapped")/bin/nvim" "$T/my-nvim-wrapped"
p3=$("$H" pane split "$p1" --direction right --cwd "$T" --no-focus | jq -r .result.pane.pane_id)
"$H" pane run "$p3" "exec $T/my-nvim-wrapped --clean -c 'nnoremap <M-d> :call writefile([\"hit\"], \"$T/marker2\")<CR>'" >/dev/null
has_my_nvim() { has_proc "$p3" my-nvim-wrapped; }
until_ 50 has_my_nvim || fail "no nvim-named process in pane (saw: $(fg_names "$p3"))"
sleep 1
focus_id "$p3"
key '\033d'
until_ 25 test -s "$T/marker2" || fail "neovim named $(fg_names "$p3") did not receive alt+d"
[ "$(focused)" = "$p3" ] || fail "focus moved although a nvim-named process was focused"
ok alt-d-reaches-any-process-named-nvim
"$H" pane close "$p3" >/dev/null

# --- 4. fail open ----------------------------------------------------------------
cat >"$T/shim" <<SH
#!/usr/bin/env bash
echo "\$*" >>"$T/shim.log"
exec "$H" "\$@"
SH
chmod +x "$T/shim"
HERDR_BIN_PATH=$T/shim HERDR_ACTIVE_PANE_ID=w9:p9 "$nav" left alt+d >/dev/null 2>&1 || true
grep -qx 'pane send-keys w9:p9 alt+d' "$T/shim.log" || fail "chord not sent for unknown pane"
ok herdr-nav-fails-open

# herdr-nav with a socket nobody listens on, then one that accepts and never
# answers: both must give the key back to the pane within two seconds.
: >"$T/shim.log"
t0=$SECONDS
HERDR_SOCKET_PATH=$T/run/nobody.sock HERDR_BIN_PATH=$T/shim HERDR_ACTIVE_PANE_ID=w9:p9 "$nav" left alt+d >/dev/null 2>&1 || true
[ $((SECONDS - t0)) -le 2 ] || fail "herdr-nav took too long with no socket"
grep -qx 'pane send-keys w9:p9 alt+d' "$T/shim.log" || fail "chord not sent when herdr is unreachable"
ok herdr-nav-fails-open-when-herdr-unreachable
python3 -I - "$T/run/hang.sock" <<'PY' &
import socket, sys, time
s = socket.socket(socket.AF_UNIX); s.bind(sys.argv[1]); s.listen(16)
time.sleep(600)
PY
hang_pid=$!
until_ 25 test -S "$T/run/hang.sock" || fail "hanging socket did not appear"
: >"$T/shim.log"
t0=$(date +%s.%N)
HERDR_SOCKET_PATH=$T/run/hang.sock HERDR_BIN_PATH=$T/shim HERDR_ACTIVE_PANE_ID=w9:p9 "$nav" left alt+d >/dev/null 2>&1 || true
el=$(echo "$(date +%s.%N) - $t0" | python3 -I -c 'print(eval(input()))')
python3 -I -c "import sys; sys.exit(0 if $el < 2 else 1)" || fail "herdr-nav took ${el}s against a hung socket"
grep -qx 'pane send-keys w9:p9 alt+d' "$T/shim.log" || fail "chord not sent when herdr hangs"
kill "$hang_pid" 2>/dev/null || true; hang_pid=
ok herdr-nav-bounded-and-fails-open-when-herdr-hangs

# No active pane: nothing to send to, so do nothing and exit 0.
: >"$T/shim.log"
env -u HERDR_ACTIVE_PANE_ID HERDR_BIN_PATH="$T/shim" "$nav" left alt+d >/dev/null 2>&1 || fail "herdr-nav without a pane id exited non-zero"
[ ! -s "$T/shim.log" ] || fail "herdr-nav without a pane id still called herdr: $(cat "$T/shim.log")"
ok herdr-nav-without-pane-id-does-nothing

# --- 5. herdr-pane placement -----------------------------------------------------
tab=$("$H" tab create --label panes --cwd "$T" | jq -r .result.tab.tab_id)
root=$(tab_panes "$tab")
a=$(HERDR_TAB_ID=$tab "$pane")
read -r ax ay aw <<<"$(rect "$a")"
total=$(snap | jq -r --arg t "$tab" '.layouts[] | select(.tab_id == $t) | .area.width')
[ "$ax" -gt 0 ] && [ "$ay" -eq 0 ] || fail "first pane not on the right ($ax,$ay)"
pct=$((aw * 100 / total))
[ "$pct" -ge 38 ] && [ "$pct" -le 42 ] || fail "right pane is $pct% wide, wanted ~40"
ok herdr-pane-one-pane-tab-right-40pct
b=$(HERDR_TAB_ID=$tab "$pane")
read -r bx by _ <<<"$(rect "$b")"
[ "$bx" -eq "$ax" ] && [ "$by" -gt "$ay" ] || fail "second pane not below the first ($bx,$by vs $ax,$ay)"
ok herdr-pane-second-call-goes-below

# --- 6. env + command + pane closes ------------------------------------------------
c=$(HERDR_TAB_ID=$tab "$pane" --env K=V -- sh -c "echo \"\$K\" > $T/envout")
until_ 25 test -s "$T/envout" || fail "command did not write its output"
[ "$(cat "$T/envout")" = V ] || fail "K was not passed (got '$(cat "$T/envout")')"
until_ 25 pane_gone "$c" || fail "pane still present after the command exited"
ok herdr-pane-env-and-exec-closes-pane

# --- 7. herdr-waiting --------------------------------------------------------------
before=$(focused)
"$waiting" || fail "herdr-waiting failed with nothing waiting"
[ "$(focused)" = "$before" ] || fail "focus moved with nothing waiting"
ok herdr-waiting-noop-when-nothing-waiting
# Bonus: a blocked agent in another tab and workspace is reached by id.
w2=$("$H" workspace create --label other --cwd "$T")
w2pane=$(jq -r .result.root_pane.pane_id <<<"$w2")
"$H" pane report-agent "$w2pane" --source check --agent claude --state blocked >/dev/null
focus_id "$p1"
"$waiting"
[ "$(focused)" = "$w2pane" ] || fail "herdr-waiting did not focus the blocked pane in another workspace"
ok herdr-waiting-focuses-blocked-pane-across-workspaces
focus_id "$p1"

# --- 8. herdr-dev ------------------------------------------------------------------
export HERDR_DEV_CLAUDE_CMD="sleep 1001" HERDR_DEV_OMP_CMD="sleep 1002"
set +e; out=$(env -u HERDR_ENV "$dev" c 2>&1); rc=$?; set -e
[ "$rc" -eq 2 ] || fail "herdr-dev outside herdr exited $rc, wanted 2"
ok herdr-dev-outside-herdr-exits-2

mkdir -p "$T/work/proj"
t1=$(cd "$T/work/proj" && "$dev" c)
[ "$(tab_json "$t1" | jq -r .label)" = proj ] || fail "tab not labelled proj"
read -ra ps <<<"$(tab_panes "$t1")"
[ "${#ps[@]}" -eq 1 ] || fail "expected one pane, got ${#ps[@]}"
until_ 50 has_proc "${ps[0]}" sleep || fail "pane not running the command (saw: $(fg_names "${ps[0]}"))"
ok herdr-dev-c-one-labelled-pane-running-command

t2=$(cd "$T/work/proj" && "$dev" co)
read -ra ps <<<"$(tab_panes "$t2")"
[ "${#ps[@]}" -eq 2 ] || fail "expected two panes, got ${#ps[@]}"
read -r x0 y0 _ <<<"$(rect "${ps[0]}")"
read -r x1 y1 _ <<<"$(rect "${ps[1]}")"
[ "$y0" -eq "$y1" ] && [ "$x0" -ne "$x1" ] || fail "panes not side by side"
ok herdr-dev-co-two-panes-side-by-side

set +e; out=$(cd "$T/work/proj" && "$dev" vx 2>&1); rc=$?; set -e
[ "$rc" -ne 0 ] && [[ $out == *usage:* ]] || fail "herdr-dev vx did not fail with usage (rc=$rc: $out)"
ok herdr-dev-bad-spec-fails-with-usage

# --- 9. worktree ---------------------------------------------------------------------
mkdir -p "$T/repo"
git -C "$T/repo" init -q
git -C "$T/repo" -c user.name=check -c user.email=check@example.invalid commit -q --allow-empty -m init
t3=$(cd "$T/repo" && "$dev" c -w feat/x)
[ -d "$T/repo-feat-x" ] || fail "worktree directory missing"
git -C "$T/repo" show-ref --verify --quiet refs/heads/feat/x || fail "branch not created"
[ "$(tab_json "$t3" | jq -r .label)" = repo-feat-x ] || fail "worktree tab not labelled repo-feat-x"
ok herdr-dev-w-creates-sibling-worktree
set +e; out=$(cd "$T/repo" && "$dev" c -w feat/x 2>&1); rc=$?; set -e
[ "$rc" -ne 0 ] && [[ $out == *"already exists"* ]] || fail "existing target not refused ($out)"
ok herdr-dev-w-refuses-existing-target
set +e; out=$(cd "$T/work" && "$dev" c -w y 2>&1); rc=$?; set -e
[ "$rc" -ne 0 ] && [[ $out == *"not inside a git repository"* ]] || fail "non-repo not refused ($out)"
ok herdr-dev-w-refuses-outside-git

# worktree from a subdirectory and from inside a linked worktree
ntabs() { "$H" tab list | jq '.result.tabs | length'; }
mkdir -p "$T/repo/sub/deeper"
t4=$(cd "$T/repo/sub/deeper" && "$dev" c -w feat/sub)
[ -d "$T/repo-feat-sub" ] || fail "sibling of the repository root missing when run from a subdirectory"
[ ! -e "$T/repo/sub/repo-feat-sub" ] && [ ! -e "$T/repo/sub/deeper-feat-sub" ] || fail "worktree created next to the subdirectory"
ok herdr-dev-w-from-subdirectory-uses-repo-root
t5=$(cd "$T/repo-feat-x" && "$dev" c -w feat/y)
[ -d "$T/repo-feat-y" ] || fail "sibling not named after the main worktree"
[ ! -e "$T/repo-feat-x-feat-y" ] || fail "sibling named after the linked worktree"
[ "$(tab_json "$t5" | jq -r .label)" = repo-feat-y ] || fail "tab not labelled repo-feat-y"
ok herdr-dev-w-from-linked-worktree-names-after-main

# a branch already checked out elsewhere: git refuses; one line, no tab
git -C "$T/repo" worktree add -q -b taken "$T/elsewhere"
before=$(ntabs)
set +e; out=$(cd "$T/repo" && "$dev" c -w taken 2>&1); rc=$?; set -e
[ "$rc" -ne 0 ] || fail "branch checked out elsewhere was accepted"
[ "$(wc -l <<<"$out")" -eq 1 ] && [[ $out == *taken* && $out == *"$T/repo-taken"* ]] || fail "not one line naming branch and directory: $out"
[ "$(ntabs)" -eq "$before" ] || fail "a tab was created although git worktree add failed"
[ ! -e "$T/repo-taken" ] || fail "target directory was left behind"
ok herdr-dev-w-git-failure-one-line-no-tab

# failure after the tab exists: the tab is closed again and the worktree named
before=$(ntabs)
set +e; out=$(cd "$T/repo" && HERDR_DEV_TEST_FAIL=1 "$dev" c -w feat/z 2>&1); rc=$?; set -e
[ "$rc" -ne 0 ] || fail "injected failure did not fail herdr-dev"
[ "$(ntabs)" -eq "$before" ] || fail "failed herdr-dev left a tab behind"
[[ $out == *"$T/repo-feat-z"* ]] || fail "message does not name the kept worktree: $out"
[ -d "$T/repo-feat-z" ] || fail "worktree was removed automatically"
ok herdr-dev-failure-after-tab-closes-tab-keeps-worktree

# env var through the second-agent path reaches the process; the pane closes
export HERDR_DEV_OMP_CMD="env K=V2 sh -c 'echo \$K > $T/envout2'"
t6=$(cd "$T/work/proj" && "$dev" co)
until_ 25 test -s "$T/envout2" || fail "second-agent command did not run"
[ "$(cat "$T/envout2")" = V2 ] || fail "K not passed to the second agent (got '$(cat "$T/envout2")')"
until_ 25 test "$(tab_panes "$t6" | wc -w)" -eq 1 || fail "second-agent pane did not close on exit"
ok herdr-dev-second-agent-env-reaches-process-and-pane-closes

echo "all checks passed"
