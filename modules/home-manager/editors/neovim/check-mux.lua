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

-- At the headless 80 columns the stack's windows are narrower than
-- 'winwidth', so focusing one resizes the others, and the
-- watcher ignores an agent's output for a second after a resize. The width of
-- the E2E terminal instead. Without a UI the window takes the new width only
-- when the windows are evened out.
vim.o.columns = 160
vim.cmd("wincmd =")
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

-- A new space: one stack window, nothing started, the sidebar hidden until
-- <leader>ms shows it on the left.
Mux.open(a)
assert(#api.nvim_list_tabpages() == 1 and fn.getcwd(-1, 0) == a, "first space did not reuse the unused tab")
assert(#api.nvim_tabpage_list_wins(0) == 1 and #stack() == 1 and api.nvim_get_current_win() == stack()[1], "the space does not start as one focused window without the sidebar")
assert(next(Mux.st) == nil and has(">1 a"), "a new space started an agent or is not listed: " .. sidebar_text())
fn.maparg("<leader>ms", "n", false, true).callback()
local side = vim.tbl_filter(function(w) return api.nvim_win_get_buf(w) == Mux.side end, api.nvim_tabpage_list_wins(0))[1]
assert(side and api.nvim_win_get_position(side)[2] == 0 and api.nvim_win_get_width(side) == 28, "<leader>ms did not show a 28-column sidebar on the left")
api.nvim_set_current_win(stack()[1])
ok("open-starts-without-the-sidebar-and-leader-ms-shows-it")

-- Navigating: plain hjkl move between windows until <CR> enters one, and
-- <Esc> steps back out. In the panel j and k are list motions up to its
-- edges, here its one line.
local function press(lhs) return fn.maparg(lhs, "n", false, true).callback() end
assert(Mux.nav == true and press("h"):find("wincmd h") and press("j"):find("wincmd j"), "a new mux does not start navigating")
press("<CR>")
assert(Mux.nav == false and press("h") == "h" and press("<CR>") == "<CR>", "enter did not hand the keys back to vim")
press("<Esc>")
assert(Mux.nav == true and Mux.tabline():find(" NAV ", 1, true), "escape did not step back out, or the tabline does not say so")
api.nvim_set_current_win(side)
assert(press("j"):find("wincmd j") and press("k"):find("wincmd k") and press("l"):find("wincmd l"), "j and k past the panel's edges do not leave it")
api.nvim_set_current_win(stack()[1])
ok("navigate-with-hjkl-enter-and-escape")

-- Launching: the first item takes the start window, the next ones split the
-- newest window as Hyprland's dwindle layout does; the panel keeps its 28 columns.
vim.cmd("ClaudeCode")
local claude_a = api.nvim_get_current_buf()
assert(#stack() == 1 and Mux.st[claude_a].name == "claude" and Mux.claude.get_active_bufnr() == claude_a, "claude did not take the start window")
assert(Mux.nav == false, "launching an agent did not put you inside it")
local probe = Mux.agent("probe", { "sh", "-c", 'echo "$MUX_BUF" >"$0/buf"; pwd >"$0/pwd"; sleep 1002', tmp })
wait("probe output", function() return fn.filereadable(tmp .. "/pwd") == 1 end)
assert(fn.readfile(tmp .. "/buf")[1] == tostring(probe), "MUX_BUF is not the terminal's buffer")
assert(fn.readfile(tmp .. "/pwd")[1] == a, "agent did not start in the space's directory")
local claude_win = fn.win_findbuf(claude_a)[1]
-- 2, 3 and 4 windows as dwindle opens them: right of the first at full
-- height, below the second at half its height, right of the third at half its width.
local function box(w) local p = api.nvim_win_get_position(w) return p[1], p[2], api.nvim_win_get_width(w), api.nvim_win_get_height(w) end
local probe_win = api.nvim_get_current_win()
local cr, cc, cw, ch = box(claude_win)
local pr, pc, pw, ph = box(probe_win)
assert(pc > cc + cw and pr == cr and ph == ch, "2: the second window is not right of the first at full height")
assert(#stack() == 2 and api.nvim_win_get_position(0)[2] > api.nvim_win_get_position(claude_win)[2], "second item is not right of the first")
-- Halves of what the 28-column panel leaves (one column per separator).
local function halves(w1, w2) return math.abs(w1 - w2) <= 1 and w1 + w2 + 1 == vim.o.columns - 28 - 1 end
assert(halves(api.nvim_win_get_width(claude_win), api.nvim_win_get_width(0)) and api.nvim_win_get_width(side) == 28, "the two items do not split the width beside a 28-column panel")
Mux.notes()
assert(#stack() == 3 and api.nvim_buf_get_name(0) == a .. "/todo.md" and Mux.st[api.nvim_get_current_buf()] == nil, "notes did not open in the stack")
local notes_win = api.nvim_get_current_win()
local nr, nc, nw, nh = box(notes_win)
local pr3, _, _, ph3 = box(probe_win)
assert(nc == pc and nw == pw and pr3 == pr and nr == pr + ph3 + 1 and math.abs(nh - ph3) <= 1 and ph3 + nh + 1 == ph, "3: the third window is not below the second at half its height")
Mux.notes()
assert(#stack() == 3, "reopening the notes added a window")
-- :ClaudeCode starts one more claude; the plugin's own open() reuses the tab's.
vim.cmd("ClaudeCode")
assert(#stack() == 4 and Mux.st[api.nvim_get_current_buf()].name == "claude 2", "a second :ClaudeCode did not start claude 2")
local r4, c4, w4, h4 = box(0)
local nr2, nc2, nw2, nh2 = box(notes_win)
assert(r4 == nr2 and c4 > nc2 + nw2 and h4 == nh2 and math.abs(w4 - nw2) <= 1 and nw2 + w4 + 1 == pw and select(4, box(probe_win)) == ph3, "4: the fourth window is not right of the third at half its width")
ok("stack-opens-2-3-4-windows-as-hyprland-dwindle")
Mux.claude.open("sleep 1005", {})
assert(#stack() == 4 and api.nvim_get_current_buf() == claude_a, "the provider's open() did not reuse the tab's claude")
ok("launch-claude-agent-notes-and-a-second-claude")

-- A second space (a directory with a space), without the sidebar.
Mux.open(b, "c")
local claude_b = api.nvim_get_current_buf()
assert(#api.nvim_list_tabpages() == 2 and fn.getcwd(-1, 0) == b and Mux.st[claude_b].dir == b, "second space is wrong")
assert(#api.nvim_tabpage_list_wins(0) == 1 and #stack() == 1, "second space is not claude alone")
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
Mux.sidebar()
sidebar_text()
for lnum, row in pairs(Mux.rows) do
  if row.buf == probe then api.nvim_win_set_cursor(0, { lnum, 0 }) end
end
fn.maparg("<CR>", "n", false, true).callback()
assert(api.nvim_get_current_buf() == probe and api.nvim_tabpage_get_number(0) == 1, "enter on a panel row did not go to that agent")
ok("jump-order-and-panel-rows-go-to-agents-across-spaces")

-- What each agent is doing: the title its program gives the terminal (OSC 0
-- or 2) on a line under its row, kept current by the panel's timer, a target
-- like the row. Nothing (no term:// name) before the program sets one.
local titled = Mux.agent("titled", { "sh", "-c", [[sleep 0.5; printf '\033]0;First topic\007'; while [ ! -e "$0/t2" ]; do sleep 0.1; done; printf '\033]2;Second topic\007'; sleep 1009]], tmp })
assert(has("   titled   ") and not sidebar_text():find("   titled   %a+\n     ") and not has("term://"), "an agent without a title shows one: " .. sidebar_text())
local function line_of(text) -- in the panel as the timer left it
  for lnum, line in ipairs(api.nvim_buf_get_lines(Mux.side, 0, -1, false)) do
    if line == text then return lnum end
  end
end
wait("the first title", function() return line_of("     First topic") end)
local first = line_of("     First topic")
assert(api.nvim_buf_get_lines(Mux.side, first - 2, first - 1, false)[1]:find("^   titled ") and Mux.rows[first].buf == titled, "the title is not under its agent's row, or not its target: " .. sidebar_text())
fn.writefile({}, tmp .. "/t2")
wait("the changed title", function() return line_of("     Second topic") and not line_of("     First topic") end)
api.nvim_set_current_win(panel())
api.nvim_win_set_cursor(0, { line_of("     Second topic"), 0 })
fn.maparg("<CR>", "n", false, true).callback()
assert(api.nvim_get_current_buf() == titled, "enter on the title line did not go to its agent")
fn.jobstop(vim.b[titled].terminal_job_id)
wait("the titled agent to go", function() return not api.nvim_buf_is_valid(titled) end)
ok("panel-shows-each-agents-terminal-title-and-follows-it")

-- Several tabs in one space: listed once in the panel, each in the tabline.
Mux.tab()
local tab2 = api.nvim_get_current_tabpage()
assert(#api.nvim_list_tabpages() == 3 and vim.t.mux_dir == a and not panel() and #stack() == 1, "new tab is not a second tab of the space, without the panel")
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
assert(Mux.st[gone] == nil and #stack() == 1 and #api.nvim_tabpage_list_wins(0) == 1, "the stack did not survive its last agent")
assert(not has("gone"), "the exited agent is still listed")
ok("agent-exit-leaves-and-the-stack-keeps-a-window")
Mux.sidebar()

-- A file opened over an agent or the panel goes in the stack beside them: the
-- file tree and the pickers :edit in the window they were started from.
local busy = Mux.agent("busy", { "sleep", "1007" })
vim.cmd("stopinsert | edit " .. fn.fnameescape(c .. "/notes.txt"))
wait("the agent to get its window back", function() return #fn.win_findbuf(busy) == 1 and #stack() == 2 end)
local busy_win = fn.win_findbuf(busy)[1]
assert(api.nvim_buf_get_name(0) == c .. "/notes.txt" and api.nvim_win_get_position(0)[2] > api.nvim_win_get_position(busy_win)[2], "the file is not right of the agent")
assert(halves(api.nvim_win_get_width(busy_win), api.nvim_win_get_width(0)) and api.nvim_win_get_width(panel()) == 28, "the file and the agent do not split the width beside a 28-column panel")
api.nvim_set_current_win(panel())
vim.cmd("edit " .. fn.fnameescape(c .. "/other.txt"))
wait("the panel to get its window back", function() return panel() ~= nil and #stack() == 3 end)
assert(api.nvim_buf_get_name(0) == c .. "/other.txt" and #fn.win_findbuf(busy) == 1, "the file opened from the panel is not in the stack")
ok("a-file-opened-over-an-agent-or-the-panel-stacks-beside-them")

-- A panel row reaches its agent also when the stack was closed down to
-- nothing (:q on its last window): it starts again right of the panel.
for _, win in ipairs(stack()) do api.nvim_win_close(win, true) end
assert(#api.nvim_tabpage_list_wins(0) == 1 and panel(), "the stack did not close")
sidebar_text()
for lnum, row in pairs(Mux.rows) do
  if row.buf == busy then api.nvim_win_set_cursor(0, { lnum, 0 }) end
end
local went, err = pcall(fn.maparg("<CR>", "n", false, true).callback)
assert(went, "enter on the row of an agent without a window: " .. tostring(err))
assert(api.nvim_get_current_buf() == busy and #stack() == 1 and api.nvim_win_get_width(panel()) == 28, "the agent is not back right of a 28-column panel")
ok("a-panel-row-reaches-its-agent-after-the-stack-was-closed")

-- <leader>fb lists the files of this space (telescope stubbed: not loaded
-- here) and no agents; the empty buffer the start screen replaces is gone.
local picked
package.loaded["telescope.builtin"] = { buffers = function(opts) picked = opts end }
fn.maparg("<leader>fb", "n", false, true).callback()
assert(picked and picked.cwd == c and not vim.bo[busy].buflisted, "fb does not list only this space's files: " .. vim.inspect(picked))
vim.cmd("tabnew")
local replaced = api.nvim_get_current_buf()
fn.mkdir(tmp .. "/bin", "p")
fn.writefile({ "#!/bin/sh", "echo sprite" }, tmp .. "/bin/krabby")
fn.setfperm(tmp .. "/bin/krabby", "rwxr-xr-x")
vim.env.PATH = tmp .. "/bin:" .. vim.env.PATH
dofile(here .. "/lua/pokemon.lua")
api.nvim_exec_autocmds("VimEnter", {})
assert(vim.bo.buftype == "terminal" and not api.nvim_buf_is_valid(replaced), "the buffer the start screen replaced is still there")
vim.cmd("tabclose")
ok("fb-lists-only-this-spaces-files-and-no-leftover-empty-buffer")

-- A file opened over an agent that the stack already shows is gone to, as
-- the notes are: the buffer list offers the files that are open.
local notes_txt = c .. "/notes.txt"
api.nvim_set_current_win(fn.win_findbuf(busy)[1])
vim.cmd("stopinsert | edit " .. fn.fnameescape(notes_txt))
wait("the file to stack", function() return #fn.win_findbuf(busy) == 1 and #stack() == 2 end)
api.nvim_set_current_win(fn.win_findbuf(busy)[1])
vim.cmd("stopinsert | edit " .. fn.fnameescape(notes_txt))
wait("the agent to get its window back", function() return #fn.win_findbuf(busy) == 1 and api.nvim_buf_get_name(0) == notes_txt end)
assert(#stack() == 2, "a file the stack already shows got a second window")
ok("a-file-already-in-the-stack-is-gone-to-not-opened-twice")

-- Zoom, as Hyprland's fullscreen: the focused window takes the whole stack
-- beside the 28-column panel and the same key gives back the exact sizes. A
-- window opened while zoomed unzooms first; after one closed, unzooming
-- evens the sizes out.
assert(Mux.zoom and fn.maparg("<M-f>", "n", false, true).callback == Mux.zoom and fn.maparg("<M-f>", "t", false, true).callback == Mux.zoom, "alt+f does not zoom in normal and terminal mode")
busy_win = fn.win_findbuf(busy)[1]
api.nvim_set_current_win(busy_win)
local sizes, busy_width = fn.winrestcmd(), api.nvim_win_get_width(busy_win)
fn.maparg("<leader>mf", "n", false, true).callback()
assert(api.nvim_win_get_width(0) == vim.o.columns - 28 - 3 and api.nvim_win_get_width(panel()) == 28, "the zoomed window does not take the stack: " .. api.nvim_win_get_width(0))
fn.maparg("<leader>mf", "n", false, true).callback()
assert(fn.winrestcmd() == sizes and vim.t.mux_zoom == nil, "unzooming did not give the sizes back")
Mux.zoom()
local z = Mux.agent("z", { "sleep", "1010" })
assert(vim.t.mux_zoom == nil and api.nvim_win_get_width(busy_win) == busy_width, "a window opened while zoomed did not unzoom first")
api.nvim_set_current_win(busy_win)
Mux.zoom()
api.nvim_win_close(fn.win_findbuf(z)[1], true)
Mux.zoom()
local stacked = stack()
assert(vim.t.mux_zoom == nil and #stacked == 2 and halves(api.nvim_win_get_width(stacked[1]), api.nvim_win_get_width(stacked[2])), "unzooming after a window closed did not even out the sizes")
ok("zoom-toggles-the-focused-window-and-restores-the-sizes")

-- lazygit under the agents panel in a git repository (a stand-in here): in the
-- sidebar's column, not an agent, not in the stack, a target for hjkl, kept
-- running while hidden with the sidebar, zoomed over the whole tab, and a
-- file opened over it goes to the stack. No window outside a repository.
local g = tmp .. "/g"
fn.mkdir(g .. "/.git", "p")
fn.mkdir(tmp .. "/lgbin", "p")
fn.writefile({ "#!/bin/sh", 'pwd >"' .. tmp .. '/lg"; for a; do echo "$a"; done >>"' .. tmp .. '/lg"; exec sleep 1012' }, tmp .. "/lgbin/lazygit")
fn.setfperm(tmp .. "/lgbin/lazygit", "rwxr-xr-x")
vim.env.PATH = tmp .. "/lgbin:" .. vim.env.PATH
Mux.open(g)
local work = Mux.agent("work", { "sleep", "1013" })
assert(not panel() and Mux.git[g] == nil, "lazygit runs before the sidebar is shown")
Mux.sidebar()
local lg = Mux.git[g]
local lg_win = lg and fn.win_findbuf(lg)[1]
wait("lazygit to start", function() return fn.filereadable(tmp .. "/lg") == 1 end)
local started = fn.readfile(tmp .. "/lg")
assert(lg_win and api.nvim_win_get_position(lg_win)[2] == 0 and api.nvim_win_get_width(lg_win) == 28 and api.nvim_win_get_position(lg_win)[1] > api.nvim_win_get_position(panel())[1] and vim.wo[lg_win].winfixwidth, "no lazygit under the panel in its column, at its fixed width")
assert(started[1] == g and started[2] == "--use-config-file" and table.concat(fn.readfile(started[3]), "\n"):find("portraitMode: always", 1, true), "lazygit did not start in the space with its config: " .. vim.inspect(started))
assert(api.nvim_win_get_height(panel()) == api.nvim_buf_line_count(Mux.side) + 1, "the panel does not fit its list")
assert(not Mux.st[lg] and not vim.bo[lg].buflisted and not has("lazygit") and not Mux.tabline():find("lazygit", 1, true), "lazygit is listed as an agent, a buffer or a stack window")
for _, row in pairs(Mux.rows) do assert(row.buf ~= lg, "a panel row goes to lazygit") end
api.nvim_set_current_win(panel())
api.nvim_win_set_cursor(0, { 1, 0 })
press("<Esc>")
assert(press("j") == "j", "j on the panel's first line is not a list motion")
api.nvim_win_set_cursor(0, { api.nvim_buf_line_count(Mux.side), 0 })
assert(press("j"):find("wincmd j"), "j on the panel's last line does not leave it")
vim.cmd("wincmd j")
assert(api.nvim_get_current_win() == lg_win and press("k"):find("wincmd k"), "j past the panel's last line does not reach lazygit")
-- nvim-tree opening from the panel: a :vsplit of it moved to the far left.
api.nvim_set_current_win(panel())
vim.cmd("vsplit | wincmd H | vertical resize 30")
local tree_win = api.nvim_get_current_win()
-- What vim does after the resize; nvim -l never reaches the loop that fires it.
api.nvim_exec_autocmds("WinResized", {})
assert(api.nvim_win_get_width(panel()) == 28 and api.nvim_win_get_width(lg_win) == 28, "a split moved out of the sidebar widened it to " .. api.nvim_win_get_width(lg_win))
api.nvim_win_close(tree_win, true)
api.nvim_set_current_win(lg_win)
local bar = fn.winrestcmd()
Mux.zoom()
assert(api.nvim_win_get_width(lg_win) == vim.o.columns - 2 and api.nvim_win_get_height(lg_win) >= vim.o.lines - 6, "zoomed lazygit does not take the tab")
Mux.zoom()
assert(fn.winrestcmd() == bar, "unzooming lazygit did not give the sidebar back")
vim.cmd("edit " .. fn.fnameescape(g .. "/f.txt"))
wait("lazygit to get its window back", function() return api.nvim_win_get_buf(lg_win) == lg end)
assert(api.nvim_buf_get_name(0) == g .. "/f.txt" and #fn.win_findbuf(work) == 1, "the file opened over lazygit is not in the stack")
Mux.sidebar()
assert(not panel() and #fn.win_findbuf(lg) == 0 and api.nvim_buf_is_valid(lg), "lazygit did not hide with the sidebar, or stopped")
Mux.sidebar()
assert(Mux.git[g] == lg and #fn.win_findbuf(lg) == 1, "showing the sidebar again did not bring the same lazygit back")
fn.jobstop(vim.b[lg].terminal_job_id)
wait("lazygit to go when it quits", function() return not api.nvim_buf_is_valid(lg) end)
assert(panel() and #api.nvim_tabpage_list_wins(0) == #stack() + 1, "lazygit quitting closed more than its window")
Mux.open(tmp)
Mux.sidebar()
assert(panel() and #api.nvim_tabpage_list_wins(0) == #stack() + 1 and not Mux.git[tmp], "a sidebar outside a repository has lazygit")
ok("lazygit-under-the-panel-in-a-repository-hides-with-it-and-is-no-agent")

-- Entering an agent types into it only if the window still shows it: the
-- file tree splits the agent's window, then puts its own buffer in the split.
local child = fn.jobstart({ vim.v.progpath, "--embed", "--headless", "-u", "NONE", "--cmd", "let g:mux = 1" }, { rpc = true })
fn.rpcrequest(child, "nvim_command", "luafile " .. fn.fnameescape(here .. "/lua/mux.lua"))
fn.rpcrequest(child, "nvim_exec_lua", "Mux.open(...) Mux.agent('sleeper', { 'sleep', '1008' })", { c })
fn.rpcrequest(child, "nvim_input", "<C-\\><C-n>:topleft vsplit | enew<CR>")
vim.wait(300)
local mode = fn.rpcrequest(child, "nvim_get_mode").mode
fn.jobstop(child)
assert(mode == "n", "a split of an agent's window that shows something else is in mode " .. mode)
ok("no-insert-mode-in-a-split-that-stops-showing-the-agent")

io.stdout:write("all checks passed\n")
vim.cmd("qa!")
