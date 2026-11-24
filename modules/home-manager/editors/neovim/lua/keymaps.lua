-- MINIMAL set. Full revision deferred. Command-style maps = no plugin load-order issues.
local map = vim.keymap.set

map("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Find files" })
map("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", { desc = "Live grep" })
map("n", "<leader>fb", "<cmd>Telescope buffers<cr>", { desc = "Buffers" })
map("n", "<leader>e", function()
  -- si estamos en terminal, saltar a la ventana anterior
  if vim.bo.buftype == "terminal" then
    local prev = vim.fn.winnr("#")
    if prev > 0 then vim.api.nvim_set_current_win(vim.fn.win_getid(prev)) end
  end
  vim.cmd("NvimTreeToggle")
end, { desc = "File tree" })
map("n", "-", "<cmd>Oil<cr>", { desc = "Oil: parent dir" })

-- Window navigation with Alt. langmap DOES translate the key inside an Alt
-- combo in normal and terminal mode (verified in a pty: the keys labelled
-- H J K L type dvorak d h t n and fire <M-h/j/k/l>), so these are physical
-- positions. Never map <M-d>/<M-t>/<M-n>: langmap rewrites them before lookup.
-- At the edge of nvim's windows, hand the move to herdr so Alt+hjkl also
-- crosses into the neighbouring herdr pane. Async job: nvim must not block on herdr.
local herdr_dirs = { h = "left", j = "down", k = "up", l = "right" }
vim.api.nvim_create_user_command("WinNav", function(o)
  local before = vim.fn.winnr()
  vim.cmd("wincmd " .. o.fargs[1])
  if vim.fn.winnr() == before and vim.env.HERDR_ENV then
    -- The terminal-mode mappings left terminal mode before this ran; the window
    -- did not change, so go back, or herdr taking the focus would leave the
    -- buffer in normal mode.
    if o.fargs[2] == "t" then vim.cmd("startinsert") end
    vim.fn.jobstart({ vim.env.HERDR_BIN_PATH or "herdr", "pane", "focus",
      "--direction", herdr_dirs[o.fargs[1]], "--current" }, { detach = true })
  end
end, { nargs = "+" })
map("n", "<M-h>", "<Cmd>WinNav h<CR>", { desc = "Window left" })
map("n", "<M-j>", "<Cmd>WinNav j<CR>", { desc = "Window down" })
map("n", "<M-k>", "<Cmd>WinNav k<CR>", { desc = "Window up" })
map("n", "<M-l>", "<Cmd>WinNav l<CR>", { desc = "Window right" })
map("t", "<M-h>", "<C-\\><C-n><Cmd>WinNav h t<CR>", { desc = "Window left (term)" })
map("t", "<M-j>", "<C-\\><C-n><Cmd>WinNav j t<CR>", { desc = "Window down (term)" })
map("t", "<M-k>", "<C-\\><C-n><Cmd>WinNav k t<CR>", { desc = "Window up (term)" })
map("t", "<M-l>", "<C-\\><C-n><Cmd>WinNav l t<CR>", { desc = "Window right (term)" })

-- Terminal: EscEsc rápido sale a normal mode (single Esc pasa al programa)
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- claudecode.nvim: claude runs in a zellij/herdr pane beside nvim (see default.nix),
-- so there is no focus/swap keymap; Alt+hjkl moves between nvim windows and, at
-- the edge inside herdr, between herdr panes (WinNav above).
map("n", "<leader>ac", "<cmd>ClaudeCode<cr>", { desc = "New Claude pane" })
map("n", "<leader>ar", "<cmd>ClaudeCode --resume<cr>", { desc = "Resume Claude" })
map("n", "<leader>am", "<cmd>ClaudeCodeSelectModel<cr>", { desc = "Select Claude model" })
map("n", "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", { desc = "Add current buffer" })
map("x", "<leader>as", "<cmd>ClaudeCodeSend<cr>", { desc = "Send to Claude" })
map("n", "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", { desc = "Accept diff" })

-- omp (oh-my-pi) has no claudecode.nvim pairing, so this only opens a pane:
-- same placement as <leader>ac (no --direction, see default.nix); herdr-pane
-- inside herdr, foot outside zellij. A command so herdr-dev can run `nvim -c OmpPane`.
vim.api.nvim_create_user_command("OmpPane", function()
  local cwd = vim.fn.getcwd()
  local argv
  if vim.env.HERDR_ENV then
    argv = { "herdr-pane", "--cwd", cwd, "--", "omp" }
  elseif vim.env.ZELLIJ then
    argv = { "zellij", "run", "-n", "omp", "-c", "--cwd", cwd, "--", "omp" }
  else
    argv = { "foot", "--working-directory=" .. cwd, "omp" }
  end
  vim.fn.jobstart(argv, { detach = true })
end, {})
map("n", "<leader>ao", "<cmd>OmpPane<cr>", { desc = "New omp pane" })
