# herdr-waiting
#
# Focuses the first pane (any workspace, any tab) whose agent is blocked, else
# the first that is done. Nothing waiting: do nothing, exit 0.
bin=${HERDR_BIN_PATH:-herdr}

id=$("$bin" api snapshot | jq -r '.result.snapshot.panes
  | (map(select(.agent_status == "blocked"))[0]
     // map(select(.agent_status == "done"))[0]
     // empty) | .pane_id')
[ -n "$id" ] || exit 0

# The CLI can only focus a pane by direction; by id exists only as a socket
# method. pane.focus also switches to the pane's tab and workspace (verified
# against 0.9.5), so no tab.focus / workspace.focus call is needed.
: "${HERDR_SOCKET_PATH:?herdr-waiting: HERDR_SOCKET_PATH not set}"
python3 -I - "$HERDR_SOCKET_PATH" "$id" <<'PY'
import json, socket, sys
s = socket.socket(socket.AF_UNIX)
s.connect(sys.argv[1])
s.sendall((json.dumps({"id": "w", "method": "pane.focus", "params": {"pane_id": sys.argv[2]}}) + "\n").encode())
buf = b""
while not buf.endswith(b"\n"):
    chunk = s.recv(65536)
    if not chunk:
        break
    buf += chunk
sys.exit(0 if "error" not in json.loads(buf) else 1)
PY
