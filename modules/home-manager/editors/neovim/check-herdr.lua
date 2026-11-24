-- Headless check for the herdr integration. Run from anywhere:
--   nvim --headless -u NONE -l modules/home-manager/editors/neovim/check-herdr.lua
-- The provider lives inside a Nix '' string with no interpolation, so it is
-- extracted verbatim from default.nix (the build emits the same text).
local dir = debug.getinfo(1, "S").source:sub(2):match("(.*)/") or "."
local function read(p) local f = assert(io.open(p)); local s = f:read("*a"); f:close(); return s end

local nix = read(dir .. "/default.nix")
local s = assert(nix:find("external_terminal_cmd = function", 1, true))
local _, e = assert(nix:find("\n%s+end,\n", s))
local provider = assert(loadstring("return " .. nix:sub(s + #"external_terminal_cmd = ", e - 2)))()
-- Reference copy of the pre-herdr function: the zellij/foot output must not drift.
local function old(cmd, env)
  local argv = vim.env.ZELLIJ and { "zellij", "run", "-n", "claude", "-c", "--" } or { "foot" }
  argv[#argv + 1] = "env"
  for k, v in pairs(env) do argv[#argv + 1] = k .. "=" .. v end
  return vim.list_extend(argv, vim.split(cmd, " "))
end

local jobs = {}
vim.fn.jobstart = function(argv) jobs[#jobs + 1] = argv; return 1 end
dofile(dir .. "/lua/keymaps.lua")

local env = { A = "1", B = "2" }
local function press(k) vim.api.nvim_feedkeys(vim.keycode(k), "x", false) end

-- (a)
vim.env.HERDR_ENV = "1"; vim.env.ZELLIJ = "0"
local a = provider("claude --x", env)
assert(a[1] == "herdr-pane", vim.inspect(a))
local joined = " " .. table.concat(a, " ") .. " "
assert(joined:find(" --env A=1 ", 1, true) and joined:find(" --env B=2 ", 1, true), joined)
assert(table.concat(a, " "):match("%-%- claude %-%-x$"), joined)

-- (b)
vim.env.HERDR_ENV = nil
assert(vim.deep_equal(provider("claude --x", env), old("claude --x", env)))
vim.env.ZELLIJ = nil
assert(vim.deep_equal(provider("claude --x", env), old("claude --x", env)))
vim.env.ZELLIJ = "0"
assert(provider("claude --x", env)[1] == "zellij")

-- (c) edge vs. inside; vsplit leaves the cursor in the left window
vim.env.HERDR_ENV = "1"; vim.env.HERDR_BIN_PATH = "/x/herdr"
vim.cmd("only | vsplit")
vim.cmd("wincmd h")
for key, d in pairs({ ["<M-h>"] = "left", ["<M-j>"] = "down", ["<M-k>"] = "up" }) do
  jobs = {}
  press(key)
  assert(#jobs == 1 and vim.deep_equal(jobs[1],
    { "/x/herdr", "pane", "focus", "--direction", d, "--current" }), key .. vim.inspect(jobs))
end
jobs = {}
press("<M-l>") -- moves to the right window: not an edge
assert(#jobs == 0, vim.inspect(jobs))
press("<M-l>") -- now at the right edge
assert(#jobs == 1 and jobs[1][5] == "right")
-- terminal-mode map goes through the same command
assert(vim.fn.maparg("<M-h>", "t") ~= "" and vim.fn.maparg("<M-h>", "t"):find("WinNav"))

-- (c2) terminal mode at an edge: herdr takes the focus, but the buffer must
-- be back in terminal mode afterwards (the mapping leaves it first).
-- A real terminal mode cannot be entered under `-l`, so the return to it is
-- observed as the startinsert call; the terminal-mode mappings pass "t".
vim.cmd("only | terminal")
local started = 0
local real_cmd = vim.cmd
vim.cmd = setmetatable({}, { __index = real_cmd, __call = function(_, c, ...)
  if c == "startinsert" then started = started + 1 end
  return real_cmd(c, ...)
end })
jobs = {}
local tmap = vim.fn.maparg("<M-h>", "t")
assert(tmap:find("WinNav h t", 1, true), tmap)
real_cmd("WinNav h t")
assert(#jobs == 1 and started == 1, vim.inspect({ jobs, started }))
real_cmd("WinNav h") -- normal-mode mapping: no mode change
assert(started == 1)
vim.cmd = real_cmd
real_cmd("bwipeout!")

-- (c3) herdr and zellij branches tokenise the command string identically
vim.env.ZELLIJ = "0"
local cmdstr = "claude --x 'a b'  c"
vim.env.HERDR_ENV = "1"
local h = provider(cmdstr, { A = "1" })
local hwords = vim.list_slice(h, vim.fn.index(h, "--") + 2)
vim.env.HERDR_ENV = nil
local z = provider(cmdstr, { A = "1" })
local zwords = vim.list_slice(z, vim.fn.index(z, "A=1") + 2)
assert(vim.deep_equal(hwords, zwords), vim.inspect({ hwords, zwords }))
vim.env.HERDR_ENV = "1"

-- (d)
vim.env.HERDR_ENV = nil
jobs = {}
press("<M-l>"); press("<M-h>"); press("<M-h>")
assert(#jobs == 0, vim.inspect(jobs))

-- (e)
assert(vim.fn.exists(":OmpPane") == 2)
vim.env.HERDR_ENV = "1"; jobs = {}
vim.cmd("OmpPane")
assert(jobs[1][1] == "herdr-pane" and jobs[1][#jobs[1]] == "omp", vim.inspect(jobs))
vim.env.HERDR_ENV = nil; vim.env.ZELLIJ = "0"; jobs = {}
vim.cmd("OmpPane")
assert(jobs[1][1] == "zellij")
print("check-herdr: ok")
