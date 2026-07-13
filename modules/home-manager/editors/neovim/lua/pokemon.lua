-- intro-style start screen: random gen 1-3 pokemon sprite (krabby) centered,
-- with version + hints below, replacing the stock :intro
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    if vim.fn.argc() > 0 or vim.fn.executable("krabby") == 0 then
      return
    end
    local out = vim.fn.system({ "krabby", "random", "1-3", "--no-mega", "--no-gmax", "--no-regional" })
    if vim.v.shell_error ~= 0 then
      return
    end

    local sprite = vim.split(out:gsub("\n+$", ""), "\n")
    local sprite_w = 0
    for _, l in ipairs(sprite) do
      local w = vim.fn.strdisplaywidth((l:gsub("\27%[[%d;]*m", "")))
      if w > sprite_w then sprite_w = w end
    end

    local v = vim.version()
    local info = {
      ("NVIM v%d.%d.%d"):format(v.major, v.minor, v.patch),
      "",
      "<space>ff  buscar archivos",
      "<space>fg  grep",
      "<space>e   arbol",
      "q          cerrar",
    }

    local win_w = vim.api.nvim_win_get_width(0)
    local win_h = vim.api.nvim_win_get_height(0)
    local pad = string.rep(" ", math.max(0, math.floor((win_w - sprite_w) / 2)))
    local top = math.max(1, math.floor((win_h - #sprite - #info - 2) / 2))

    local lines = {}
    for _ = 1, top do lines[#lines + 1] = "" end
    for _, l in ipairs(sprite) do lines[#lines + 1] = pad .. l end
    lines[#lines + 1] = ""
    for _, l in ipairs(info) do
      local ipad = string.rep(" ", math.max(0, math.floor((win_w - vim.fn.strdisplaywidth(l)) / 2)))
      lines[#lines + 1] = ipad .. "\27[90m" .. l .. "\27[0m"
    end

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(0, buf)
    -- terminal buffer only so krabby's ANSI colors render; no process behind it
    local chan = vim.api.nvim_open_term(buf, {})
    vim.api.nvim_chan_send(chan, table.concat(lines, "\r\n"))
    vim.bo[buf].bufhidden = "wipe"
    -- processless terminal swallows keys in terminal-insert: never allow it
    vim.api.nvim_create_autocmd("TermEnter", { buffer = buf, command = "stopinsert" })
    vim.keymap.set("n", "q", "<cmd>bd!<cr>", { buffer = buf, silent = true })
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(buf) then
        pcall(vim.api.nvim_win_set_cursor, 0, { 1, 0 })
      end
    end)
  end,
})
