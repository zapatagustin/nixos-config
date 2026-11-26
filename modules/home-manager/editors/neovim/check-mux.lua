-- Headless check for the multiplexer prototype (lua/mux.lua). Run from anywhere:
--   nvim --headless -u NONE -l modules/home-manager/editors/neovim/check-mux.lua
-- Starts only `sh`, `sleep` and this same nvim as an RPC client; never claude or omp.
local here = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")
local api, fn = vim.api, vim.fn
local function ok(name) io.stdout:write("ok " .. name .. "\n") end
local function wait(what, cond, ms)
  assert(vim.wait(ms or 5000, cond, 20), "timed out: " .. what)
end

-- Without g:mux the file defines nothing.
dofile(here .. "/lua/mux.lua")
assert(Mux == nil, "Mux defined outside vdev")
ok("inert-without-g-mux")

vim.g.mux = 1
dofile(here .. "/lua/mux.lua")
-- claudecode.nvim is not loaded here: its command is the provider's toggle.
api.nvim_create_user_command("ClaudeCode", function() Mux.claude.simple_toggle("sleep 1001", {}) end, {})

-- The functions claudecode.nvim requires of a provider table (terminal.lua).
for _, f in ipairs({ "setup", "open", "close", "simple_toggle", "focus_toggle", "get_active_bufnr", "is_available" }) do
  assert(type(Mux.claude[f]) == "function", "provider lacks " .. f)
end
ok("claude-provider-has-the-required-functions")

local tmp = fn.resolve(fn.tempname())
local a, b, c = tmp .. "/a", tmp .. "/b b", tmp .. "/c"
for _, dir in ipairs({ a, b, c }) do fn.mkdir(dir, "p") end
local function stack() -- windows of the current tab that are not the sidebar
  return vim.tbl_filter(function(w) return api.nvim_win_get_buf(w) ~= Mux.side end, api.nvim_tabpage_list_wins(0))
end
local function sidebar_text()
  Mux.render()
  return table.concat(api.nvim_buf_get_lines(Mux.side, 0, -1, false), "\n")
end
local function has(text) return sidebar_text():find(text, 1, true) ~= nil end

-- A new space: the sidebar on the left, one stack window, nothing started.
Mux.open(a)
assert(#api.nvim_list_tabpages() == 1 and fn.getcwd(-1, 0) == a, "first space did not reuse the unused tab")
local side = vim.tbl_filter(function(w) return api.nvim_win_get_buf(w) == Mux.side end, api.nvim_tabpage_list_wins(0))[1]
assert(side and api.nvim_win_get_position(side)[2] == 0 and api.nvim_win_get_width(side) == 28, "no 28-column sidebar on the left")
assert(#stack() == 1 and api.nvim_get_current_win() == stack()[1], "the stack is not one focused window")
assert(next(Mux.st) == nil and has(">1 a"), "a new space started an agent or is not listed: " .. sidebar_text())
ok("open-shows-sidebar-and-start-window-without-agents")

-- Navigating: plain hjkl move between windows until <CR> enters one, and
-- <Esc> steps back out. In the panel j and k stay list motions.
local function press(lhs) return fn.maparg(lhs, "n", false, true).callback() end
assert(Mux.nav == true and press("h"):find("wincmd h") and press("j"):find("wincmd j"), "a new mux does not start navigating")
press("<CR>")
assert(Mux.nav == false and press("h") == "h" and press("<CR>") == "<CR>", "enter did not hand the keys back to vim")
press("<Esc>")
assert(Mux.nav == true and Mux.tabline():find(" NAV ", 1, true), "escape did not step back out, or the tabline does not say so")
api.nvim_set_current_win(side)
assert(press("j") == "j" and press("k") == "k" and press("l"):find("wincmd l"), "the panel does not keep j and k as list motions")
api.nvim_set_current_win(stack()[1])
ok("navigate-with-hjkl-enter-and-escape")

-- Launching: the first item takes the start window, the next ones stack below
-- at equal heights.
vim.cmd("ClaudeCode")
local claude_a = api.nvim_get_current_buf()
assert(#stack() == 1 and Mux.st[claude_a].name == "claude" and Mux.claude.get_active_bufnr() == claude_a, "claude did not take the start window")
assert(Mux.nav == false, "launching an agent did not put you inside it")
local probe = Mux.agent("probe", { "sh", "-c", 'echo "$MUX_BUF" >"$0/buf"; pwd >"$0/pwd"; sleep 1002', tmp })
wait("probe output", function() return fn.filereadable(tmp .. "/pwd") == 1 end)
assert(fn.readfile(tmp .. "/buf")[1] == tostring(probe), "MUX_BUF is not the terminal's buffer")
assert(fn.readfile(tmp .. "/pwd")[1] == a, "agent did not start in the space's directory")
local claude_win = fn.win_findbuf(claude_a)[1]
assert(#stack() == 2 and api.nvim_win_get_position(0)[1] > api.nvim_win_get_position(claude_win)[1], "second item is not below the first")
assert(math.abs(api.nvim_win_get_height(claude_win) - api.nvim_win_get_height(0)) <= 1 and api.nvim_win_get_height(0) > 3, "the two items are not the same height")
Mux.notes()
assert(#stack() == 3 and api.nvim_buf_get_name(0) == a .. "/todo.md" and Mux.st[api.nvim_get_current_buf()] == nil, "notes did not open in the stack")
Mux.notes()
assert(#stack() == 3, "reopening the notes added a window")
-- :ClaudeCode starts one more claude; the plugin's own open() reuses the tab's.
vim.cmd("ClaudeCode")
assert(#stack() == 4 and Mux.st[api.nvim_get_current_buf()].name == "claude 2", "a second :ClaudeCode did not start claude 2")
Mux.claude.open("sleep 1005", {})
assert(#stack() == 4 and api.nvim_get_current_buf() == claude_a, "the provider's open() did not reuse the tab's claude")
ok("launch-claude-agent-notes-stacked-at-equal-heights-and-a-second-claude")

-- A second space (a directory with a space) with its own sidebar window.
Mux.open(b, "c")
local claude_b = api.nvim_get_current_buf()
assert(#api.nvim_list_tabpages() == 2 and fn.getcwd(-1, 0) == b and Mux.st[claude_b].dir == b, "second space is wrong")
assert(#api.nvim_tabpage_list_wins(0) == 2 and #stack() == 1, "second space is not sidebar + claude")
assert(has(" 1 a\n   claude   idle\n   probe    idle\n   claude 2 idle\n>2 b b\n   claude   idle"), "sidebar: " .. sidebar_text())
Mux.open(a)
assert(#api.nvim_list_tabpages() == 2 and fn.getcwd(-1, 0) == a, "reopening a space made a new tab")
assert(not pcall(Mux.open, tmp, "x"), "bad SPEC accepted")
ok("spaces-listed-with-their-agents-and-reopen-switches")

-- The watcher: output while you look elsewhere is "working"; once it goes
-- quiet the agent is "done" until you visit it.
local chatty = Mux.agent("chatty", { "sh", "-c", "sleep 1.5; for i in 1 2 3 4 5; do echo line $i; sleep 0.2; done; sleep 1003" })
Mux.notes()
wait("working", function() return Mux.status(chatty) == "working" end)
assert(has("   chatty   working"), "sidebar: " .. sidebar_text())
wait("done after going quiet", function() return Mux.status(chatty) == "done" end, 8000)
api.nvim_set_current_win(fn.win_findbuf(chatty)[1])
assert(Mux.status(chatty) == "idle", "visiting did not clear the agent")
ok("watcher-working-then-done-then-idle-after-a-visit")

-- What a hook does: reach this editor through $NVIM and flag its own buffer.
local hook = string.format([["%s" --server "$NVIM" --remote-expr "v:lua.Mux.signal($MUX_BUF, 'blocked')"; sleep 1004]], vim.v.progpath)
local hooked = Mux.agent("hooked", { "sh", "-c", hook })
Mux.notes()
wait("signal through $NVIM", function() return Mux.status(hooked) == "blocked" end)
assert(has("   hooked   blocked"), "sidebar: " .. sidebar_text())
ok("hook-signals-its-buffer-through-NVIM")

-- The jump: blocked first, then finished; and the sidebar rows are targets.
assert(Mux.signal(claude_b, "done") == 1 and Mux.status(claude_b) == "done")
Mux.jump()
assert(api.nvim_get_current_buf() == hooked and Mux.status(hooked) ~= "blocked", "jump did not go to the blocked agent")
Mux.jump()
assert(api.nvim_get_current_buf() == claude_b and api.nvim_tabpage_get_number(0) == 2, "jump did not cross to the other space")
Mux.jump() -- nothing is waiting: stays put
assert(api.nvim_get_current_buf() == claude_b)
local function panel() -- the agents panel's window in the current tab, if open
  return vim.tbl_filter(function(w) return api.nvim_win_get_buf(w) == Mux.side end, api.nvim_tabpage_list_wins(0))[1]
end
api.nvim_set_current_win(panel())
sidebar_text()
for lnum, row in pairs(Mux.rows) do
  if row.buf == probe then api.nvim_win_set_cursor(0, { lnum, 0 }) end
end
fn.maparg("<CR>", "n", false, true).callback()
assert(api.nvim_get_current_buf() == probe and api.nvim_tabpage_get_number(0) == 1, "enter on a panel row did not go to that agent")
ok("jump-order-and-panel-rows-go-to-agents-across-spaces")

-- Several tabs in one space: listed once in the panel, each in the tabline.
Mux.tab()
local tab2 = api.nvim_get_current_tabpage()
assert(#api.nvim_list_tabpages() == 3 and vim.t.mux_dir == a and panel() and #stack() == 1, "new tab is not a second tab of the space")
assert(select(2, sidebar_text():gsub("%d a\n", "")) == 1, "the space is listed more than once: " .. sidebar_text())
local extra = Mux.agent("extra", { "sleep", "1006" })
assert(has("   extra    idle") and Mux.tabline():find("%%#TabLineSel# 2 extra "), "tabline: " .. Mux.tabline())
assert(Mux.tabline():find(" 1 claude + probe + todo.md + claude 2 ", 1, true), "tabline: " .. Mux.tabline())
Mux.go(1)
assert(api.nvim_tabpage_get_number(0) == 1, "tab 1 of the space is not the first tabpage")
Mux.go(nil, 1)
assert(api.nvim_get_current_tabpage() == tab2, "next tab of the space is not its second tab")
Mux.go(nil, 1)
Mux.open(b)
Mux.open(a)
assert(api.nvim_tabpage_get_number(0) == 1, "returning to a space did not land on the tab it was left on")
ok("several-tabs-per-space-with-tabline-and-switching")

-- Sending a window to another tab of the space, as a window manager would:
-- it moves, you stay. One past the last tab makes a new one.
api.nvim_set_current_win(fn.win_findbuf(probe)[1])
local before = #stack()
Mux.send(2)
assert(api.nvim_tabpage_get_number(0) == 1 and #stack() == before - 1, "send did not take the window away and stay here")
assert(#fn.win_findbuf(probe) == 1 and api.nvim_win_get_tabpage(fn.win_findbuf(probe)[1]) == tab2, "the window is not in tab 2")
assert(Mux.st[probe] and has("   probe    "), "the agent did not survive the move")
Mux.send(9) -- neither an existing tab nor the next one
assert(#stack() == before - 1 and #api.nvim_list_tabpages() == 3, "send to a tab that cannot exist did something")
api.nvim_set_current_win(fn.win_findbuf(claude_a)[1])
Mux.send(3)
assert(#api.nvim_list_tabpages() == 4 and api.nvim_tabpage_get_number(0) == 1 and vim.t[api.nvim_win_get_tabpage(fn.win_findbuf(claude_a)[1])].mux_dir == a, "send to the next number did not make a new tab of the space")
assert(type(Mux.init) == "string", "the server does not record the config it loaded")
ok("send-window-to-another-tab-and-stay")

-- The panel opens and closes with one call, like the file tree; keys are
-- <leader> or Alt chords only.
Mux.sidebar()
assert(not panel(), "the panel did not close")
Mux.sidebar()
assert(panel() and api.nvim_get_current_win() == panel(), "the panel did not reopen")
for _, key in ipairs({ "c", "o", "n", "t" }) do
  assert(fn.maparg(key, "n") == "", "bare key " .. key .. " is mapped in the panel")
end
for _, key in ipairs({ "<M-H>", "<M-J>", "<M-K>", "<M-L>", "<M-a>", "<M-2>" }) do
  assert(fn.maparg(key, "n") ~= "" or fn.maparg(key, "n", false, true).callback, key .. " is not mapped in normal mode")
  assert(fn.maparg(key, "t") ~= "" or fn.maparg(key, "t", false, true).callback, key .. " is not mapped in terminal mode")
end
ok("panel-toggles-and-keys-are-leader-or-alt-chords")

assert(Mux.signal(99999, "done") == 0 and Mux.signal(Mux.side, "done") == 0, "signal accepted a buffer that is not an agent")
ok("signal-ignores-buffers-that-are-not-agents")

-- An agent that exits leaves; a stack that loses its only item keeps a window.
Mux.open(c)
local gone = Mux.agent("gone", { "true" })
wait("exited agent's buffer to go", function() return not api.nvim_buf_is_valid(gone) end)
assert(Mux.st[gone] == nil and #stack() == 1 and #api.nvim_tabpage_list_wins(0) == 2, "the stack did not survive its last agent")
assert(not has("gone"), "the exited agent is still listed")
ok("agent-exit-leaves-and-the-stack-keeps-a-window")

io.stdout:write("all checks passed\n")
vim.cmd("qa!")
