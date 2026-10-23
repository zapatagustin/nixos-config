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
map("n", "<M-h>", "<Cmd>wincmd h<CR>", { desc = "Window left" })
map("n", "<M-j>", "<Cmd>wincmd j<CR>", { desc = "Window down" })
map("n", "<M-k>", "<Cmd>wincmd k<CR>", { desc = "Window up" })
map("n", "<M-l>", "<Cmd>wincmd l<CR>", { desc = "Window right" })
map("t", "<M-h>", "<C-\\><C-n><Cmd>wincmd h<CR>", { desc = "Window left (term)" })
map("t", "<M-j>", "<C-\\><C-n><Cmd>wincmd j<CR>", { desc = "Window down (term)" })
map("t", "<M-k>", "<C-\\><C-n><Cmd>wincmd k<CR>", { desc = "Window up (term)" })
map("t", "<M-l>", "<C-\\><C-n><Cmd>wincmd l<CR>", { desc = "Window right (term)" })

-- Terminal: EscEsc rápido sale a normal mode (single Esc pasa al programa)
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- claudecode.nvim: claude runs in a zellij pane beside nvim (see default.nix),
-- so there is no focus/swap keymap; Alt+arrows move between zellij panes.
map("n", "<leader>ac", "<cmd>ClaudeCode<cr>", { desc = "New Claude pane" })
map("n", "<leader>ar", "<cmd>ClaudeCode --resume<cr>", { desc = "Resume Claude" })
map("n", "<leader>am", "<cmd>ClaudeCodeSelectModel<cr>", { desc = "Select Claude model" })
map("n", "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", { desc = "Add current buffer" })
map("x", "<leader>as", "<cmd>ClaudeCodeSend<cr>", { desc = "Send to Claude" })
map("n", "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", { desc = "Accept diff" })
map("n", "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", { desc = "Deny diff" })
