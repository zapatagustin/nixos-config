-- Headless check for the multiplexer prototype (lua/mux.lua). Run from anywhere:
--   nvim --headless -u NONE -l modules/home-manager/editors/neovim/check-mux.lua
-- Starts only `sh`, `sleep` and this same nvim as an RPC client; never claude or omp.
local here = debug.getinfo(1, "S").source:sub(2):match("(.*)/")
local api, fn = vim.api, vim.fn
local function ok(name) io.stdout:write("ok " .. name .. "\n") end
local function wait(what, cond)
  assert(vim.wait(5000, cond, 20), "timed out: " .. what)
end

-- Without g:mux the file defines nothing.
dofile(here .. "/lua/mux.lua")
assert(Mux == nil, "Mux defined outside vdev")
ok("inert-without-g-mux")

vim.g.mux = 1
vim.g.mux_notify_shim = "/shim"
dofile(here .. "/lua/mux.lua")
-- claudecode.nvim is not loaded here: its command is the provider's toggle.
api.nvim_create_user_command("ClaudeCode", function() Mux.claude.simple_toggle("sleep 1001", {}) end, {})

-- The functions claudecode.nvim requires of a provider table (terminal.lua).
for _, f in ipairs({ "setup", "open", "close", "simple_toggle", "focus_toggle", "get_active_bufnr", "is_available" }) do
  assert(type(Mux.claude[f]) == "function", "provider lacks " .. f)
end
ok("claude-provider-has-the-required-functions")

local tmp = fn.resolve(fn.tempname())
local a, b = tmp .. "/a", tmp .. "/b b"
fn.mkdir(a, "p")
fn.mkdir(b, "p")
local function agents(name)
  return vim.tbl_filter(function(buf) return vim.b[buf].mux_agent == name end, api.nvim_list_bufs())
end

-- First project: the server's unused tab, editor on the left, claude on the right.
Mux.open(a, "vc")
assert(#api.nvim_list_tabpages() == 1, "first project did not reuse the unused tab")
assert(fn.getcwd(-1, 0) == a, "tab cwd is " .. fn.getcwd(-1, 0))
local claude_a = agents("claude")[1]
assert(claude_a and Mux.claude.get_active_bufnr() == claude_a, "no claude terminal in the tab")
assert(#api.nvim_tabpage_list_wins(0) == 2 and vim.b.mux_agent == nil, "editor window is not the current one")
local claude_win = fn.win_findbuf(claude_a)[1]
assert(api.nvim_win_get_position(claude_win)[2] > 0, "claude is not right of the editor")
assert(api.nvim_win_get_width(claude_win) == math.floor(vim.o.columns * 0.4), "agent column is not 40% wide")
ok("open-first-project-editor-left-claude-right")

-- Second project (a directory with a space): its own tab, agents only.
Mux.open(b, "c")
assert(#api.nvim_list_tabpages() == 2 and fn.getcwd(-1, 0) == b, "second project has no tab of its own")
assert(#api.nvim_tabpage_list_wins(0) == 1 and vim.b.mux_agent == "claude", "agents-only tab kept an editor window")
local claude_b = api.nvim_get_current_buf()
ok("open-second-project-own-tab-agents-only")

Mux.open(a)
assert(#api.nvim_list_tabpages() == 2 and fn.getcwd(-1, 0) == a, "reopening a project made a new tab")
assert(not pcall(Mux.open, tmp, "x"), "bad SPEC accepted")
ok("open-existing-project-switches-and-bad-spec-fails")

-- A second :ClaudeCode in the tab focuses the first; a second agent goes below it.
vim.cmd("ClaudeCode")
assert(api.nvim_get_current_buf() == claude_a and #agents("claude") == 2, "second :ClaudeCode started another claude")
local probe = Mux.agent("probe", { "sh", "-c", 'echo "$MUX_BUF" >"$0/buf"; echo "$PATH" >"$0/path"; pwd >"$0/pwd"; sleep 1002', tmp })
wait("probe output", function() return fn.filereadable(tmp .. "/pwd") == 1 end)
assert(fn.readfile(tmp .. "/buf")[1] == tostring(probe), "MUX_BUF is not the terminal's buffer")
assert(vim.startswith(fn.readfile(tmp .. "/path")[1], "/shim:"), "the notify-send shim is not first in PATH")
assert(fn.readfile(tmp .. "/pwd")[1] == a, "agent did not start in the project directory")
local cpos, ppos = api.nvim_win_get_position(claude_win), api.nvim_win_get_position(0)
assert(ppos[2] == cpos[2] and ppos[1] > cpos[1], "second agent is not below the first")
ok("agent-gets-buffer-id-shim-path-project-cwd-and-stacks-below")

-- What a hook does: reach this editor through $NVIM and flag its own buffer.
local hook = string.format([["%s" --server "$NVIM" --remote-expr "v:lua.Mux.signal($MUX_BUF, 'blocked')"; sleep 1003]], vim.v.progpath)
api.nvim_set_current_win(fn.win_findbuf(claude_a)[1])
local hooked = Mux.agent("hooked", { "sh", "-c", hook })
vim.cmd("wincmd t") -- look at the editor, away from the agents
wait("signal through $NVIM", function() return vim.b[hooked].mux_state == "blocked" end)
ok("hook-signals-its-buffer-through-NVIM")

-- Tabline marks, and the jump: blocked first, then finished, oldest first.
assert(Mux.signal(claude_b, "done") == 1 and Mux.signal(probe, "done") == 1)
assert(Mux.tabline():find(" a ! ", 1, true), "blocked project not marked: " .. Mux.tabline())
assert(Mux.tabline():find(" b b * ", 1, true), "finished project not marked: " .. Mux.tabline())
Mux.jump()
assert(api.nvim_get_current_buf() == hooked and vim.b[hooked].mux_state == nil, "jump did not go to the blocked agent")
Mux.jump()
assert(api.nvim_get_current_buf() == claude_b and api.nvim_tabpage_get_number(0) == 2, "jump did not cross to the other tab")
Mux.jump()
assert(api.nvim_get_current_buf() == probe, "jump did not go to the last waiting agent")
assert(not Mux.tabline():find("[!*]"), "marks left after visiting every agent")
Mux.jump() -- nothing is waiting: stays put
assert(api.nvim_get_current_buf() == probe)
ok("tabline-marks-and-jump-order-across-tabs")

assert(Mux.signal(99999, "done") == 0, "signal accepted an unknown buffer")
vim.cmd("wincmd t")
assert(Mux.signal(api.nvim_get_current_buf(), "done") == 0, "signal flagged a buffer that is not an agent")
ok("signal-ignores-unknown-and-non-agent-buffers")

-- An agent that exits takes its window with it.
local gone = Mux.agent("gone", { "true" })
wait("exited agent's buffer to go", function() return not api.nvim_buf_is_valid(gone) end)
ok("agent-exit-closes-its-window")

io.stdout:write("all checks passed\n")
vim.cmd("qa!")
