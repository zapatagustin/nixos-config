-- Physical (QWERTY-position) keys must reach which-key's triggers through 'langmap'
-- whether typed fast or slowly; see the which-key config in default.nix. Drives a
-- child nvim that loads the user config found through XDG_CONFIG_HOME/XDG_DATA_HOME
-- (the flake check `nvim-which-key-langmap` points them at the built config; run by
-- hand it tests the deployed one):
--   nvim --headless -u NONE -l modules/home-manager/editors/neovim/check-langmap.lua
local fn = vim.fn
local child = fn.jobstart({ vim.v.progpath, "--embed", "--headless" }, { rpc = true })
local function rq(...) return fn.rpcrequest(child, ...) end
local function lua(code, ...) return rq("nvim_exec_lua", code, { ... }) end

-- Dvorak character on the physical key that langmap turns into `c`.
local phys = {}
for _, item in ipairs(fn.split(rq("nvim_get_option_value", "langmap", {}), [[[^\\]\zs,]])) do
  local s = item:gsub("\\(.)", "%1")
  phys[s:sub(2, 2)] = s:sub(1, 1)
end
assert(phys.f == "u" and phys.g == "i", "this check assumes the Dvorak langmap of lua/options.lua")

-- Fast = all keys in one read, like a terminal delivers a burst. Slow = one key per
-- 'timeoutlen' + margin, so which-key's trigger has taken over and reads the rest
-- itself (the case that used to miss).
local gap = rq("nvim_get_option_value", "timeoutlen", {}) + 300
local function type_keys(keys, slow)
  if not slow then rq("nvim_input", keys) end
  for i = 1, slow and #keys or 0 do
    rq("nvim_input", keys:sub(i, i))
    vim.wait(gap)
  end
  vim.wait(gap)
  rq("nvim_input", "<Esc>")
  vim.wait(100)
end

-- The real <leader>ff runs Telescope; a recorder stands in so only the mapping is tested.
lua([[vim.keymap.set("n", "<leader>ff", function() vim.g.hit = "ff" end, { desc = "Find files" })]])
lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.fn.map(vim.fn.range(1, 20), "string(v:val)"))]])
assert(lua([[return package.loaded["which-key"] ~= nil]]), "which-key not loaded")

local fails = 0
local function expect(name, got, want)
  local ok = got == want
  fails = fails + (ok and 0 or 1)
  io.stdout:write(("%s %s (got %s, want %s)\n"):format(ok and "ok" or "FAIL", name, vim.inspect(got), vim.inspect(want)))
end

for _, slow in ipairs({ false, true }) do
  local speed = slow and "slow" or "fast"
  lua("vim.g.hit = nil")
  type_keys(" " .. phys.f .. phys.f, slow)
  expect(speed .. " physical <leader>ff", lua("return vim.g.hit"), "ff")

  lua("vim.api.nvim_win_set_cursor(0, { 20, 0 })")
  type_keys(phys.g .. phys.g, slow)
  expect(speed .. " physical gg", lua([[return vim.fn.line(".")]]), 1)
end

fn.jobstop(child)
if fails > 0 then
  io.stderr:write(fails .. " failed: which-key reads keys past 'langmap' again (see default.nix)\n")
  os.exit(1)
end
