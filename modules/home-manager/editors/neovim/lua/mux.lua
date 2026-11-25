-- Neovim as the terminal multiplexer. PROTOTYPE, to compare in use with herdr
-- (shells/herdr); nothing here runs in an ordinary nvim.
--
-- Active only in the editor that the `vdev` shell function starts with
-- `--cmd "let g:mux = 1"`: a headless server that terminals attach to with
-- --remote-ui, so the agents keep running after :detach or a closed terminal.
-- One tabpage per project, its agents in :terminal buffers of that tab. The
-- rest is stock vim: windows are the panes (CTRL-W, :split, :q) and tabpages
-- are the workspaces (gt, :tabclose).
if vim.g.mux then
  local api, fn = vim.api, vim.fn
  local M = {}
  _G.Mux = M
  local group = api.nvim_create_augroup("mux", {})

  -- Windows of a tabpage that show an agent terminal, in window order.
  local function agent_wins(tab)
    return vim.tbl_filter(function(w)
      return vim.b[api.nvim_win_get_buf(w)].mux_agent ~= nil
    end, api.nvim_tabpage_list_wins(tab))
  end

  -- Next to an editor window the agents share a right-hand column 40% wide.
  -- Applied again on every screen size change: the server lays the windows out
  -- at 80 columns before a UI attaches.
  local function fit(tab)
    local agents = agent_wins(tab)
    if agents[1] and #api.nvim_tabpage_list_wins(tab) > #agents then
      api.nvim_win_set_width(agents[1], math.floor(vim.o.columns * 0.4))
    end
  end

  -- Starts `cmd` in a new terminal window of the current tab and returns its
  -- buffer: right of the editor for the first agent, below the last agent
  -- otherwise. $MUX_BUF tells the agent's hooks which buffer to flag (M.signal).
  function M.agent(name, cmd, env)
    local agents = agent_wins(0)
    if agents[1] then
      api.nvim_set_current_win(agents[#agents])
      vim.cmd("belowright new")
    else
      vim.cmd("botright vnew")
    end
    local buf = api.nvim_get_current_buf()
    vim.b[buf].mux_agent = name
    env = vim.tbl_extend("force", env or {}, { MUX_BUF = tostring(buf) })
    -- ecomono: the notify-send shim (default.nix) is how an agent without hooks
    -- reports "done". Unverified that omp reaches notify-send through PATH from
    -- a :terminal. Upgrade: an omp extension that calls Mux.signal itself.
    if vim.g.mux_notify_shim then env.PATH = vim.g.mux_notify_shim .. ":" .. vim.env.PATH end
    fn.jobstart(cmd, { term = true, cwd = fn.getcwd(-1, 0), env = env })
    fit(0)
    vim.cmd("startinsert")
    return buf
  end

  -- Called by an agent through $NVIM (claude-notify in ../../ai, the notify-send
  -- shim): "blocked" = needs an answer now, "done" = its turn finished. Returns
  -- a number because --remote-expr prints the result.
  function M.signal(buf, state)
    if not api.nvim_buf_is_valid(buf) or not vim.b[buf].mux_agent then return 0 end
    -- No flag for the agent that is being looked at.
    if buf == api.nvim_get_current_buf() and #api.nvim_list_uis() > 0 then return 0 end
    vim.b[buf].mux_state = state
    vim.b[buf].mux_since = vim.uv.hrtime()
    vim.cmd("redrawtabline")
    return 1
  end

  -- Goes to the agent that has waited longest, blocked ones before finished ones.
  function M.jump()
    local best, best_rank
    for _, buf in ipairs(api.nvim_list_bufs()) do
      local state = vim.b[buf].mux_state
      if state then
        local rank = (state == "blocked" and 0 or 1e18) + vim.b[buf].mux_since
        if not best_rank or rank < best_rank then best, best_rank = buf, rank end
      end
    end
    if not best then return vim.notify("mux: no agent is waiting") end
    local win = fn.win_findbuf(best)[1]
    if win then
      api.nvim_set_current_win(win) -- also switches tabpage
    else
      vim.cmd("sbuffer " .. best) -- its window was closed; the agent kept running
    end
  end

  -- Entry point of `vdev`, through --remote-expr: the tab of project `dir`,
  -- created with the agents of `spec` (letters v c o, as herdr-dev) if missing.
  function M.open(dir, spec)
    spec = (spec or "") ~= "" and spec or "vco"
    if not spec:match("^[vco]+$") then error("vdev: bad SPEC '" .. spec .. "' (letters v c o)") end
    local tabs = api.nvim_list_tabpages()
    for _, tab in ipairs(tabs) do
      if vim.t[tab].mux_dir == dir then
        api.nvim_set_current_tabpage(tab)
        return 1
      end
    end
    -- A new server has one unused tab; every later project gets its own.
    if vim.iter(tabs):any(function(t) return vim.t[t].mux_dir ~= nil end) then vim.cmd("tabnew") end
    vim.cmd("tcd " .. fn.fnameescape(dir))
    vim.t.mux_dir = dir
    local editor = api.nvim_get_current_win()
    if spec:find("c") then vim.cmd("ClaudeCode") end
    if spec:find("o") then M.agent("omp", "omp") end
    if spec:find("v") or not agent_wins(0)[1] then
      api.nvim_set_current_win(editor)
      vim.cmd("stopinsert")
    else
      api.nvim_win_close(editor, false) -- agents only: they take the whole tab
    end
    return 1
  end

  function M.projects()
    vim.ui.select(api.nvim_list_tabpages(), {
      prompt = "Project",
      format_item = function(tab)
        return vim.t[tab].mux_dir or ("tab " .. api.nvim_tabpage_get_number(tab))
      end,
    }, function(tab)
      if tab then api.nvim_set_current_tabpage(tab) end
    end)
  end

  -- The workspace list: one entry per tabpage, named after its project, with
  -- "!" while an agent in it is blocked and "*" while one has finished.
  function M.tabline()
    local parts = {}
    for i, tab in ipairs(api.nvim_list_tabpages()) do
      local mark = ""
      for _, win in ipairs(api.nvim_tabpage_list_wins(tab)) do
        local state = vim.b[api.nvim_win_get_buf(win)].mux_state
        if state == "blocked" then
          mark = " !"
        elseif state and mark == "" then
          mark = " *"
        end
      end
      local dir = vim.t[tab].mux_dir
      parts[#parts + 1] = (tab == api.nvim_get_current_tabpage() and "%#TabLineSel#" or "%#TabLine#")
        .. "%" .. i .. "T " .. i .. " " .. (dir and vim.fs.basename(dir) or "-") .. mark .. " "
    end
    return table.concat(parts) .. "%#TabLineFill#%T"
  end
  vim.o.showtabline = 2
  vim.o.tabline = "%!v:lua.Mux.tabline()"

  -- claudecode.nvim terminal provider (see its entry in default.nix): claude in
  -- a :terminal of the current tab instead of a herdr pane.
  -- ecomono: one claude per tab, so a second :ClaudeCode there only focuses the
  -- first and `:ClaudeCode --resume` needs it closed first. Selections are
  -- broadcast to every claude of this editor, whatever its tab. Upgrade:
  -- several per tab keyed by the command string; one editor per project.
  local function claude_buf()
    for _, win in ipairs(agent_wins(0)) do
      local buf = api.nvim_win_get_buf(win)
      if vim.b[buf].mux_agent == "claude" then return buf, win end
    end
  end
  local function claude_open(cmd, env, _, focus)
    local prev = api.nvim_get_current_win()
    local _, win = claude_buf()
    if win then api.nvim_set_current_win(win) else M.agent("claude", cmd, env) end
    if focus == false then
      api.nvim_set_current_win(prev)
      if not vim.b.mux_agent then vim.cmd("stopinsert") end
    end
  end
  M.claude = {
    setup = function() end,
    is_available = function() return true end,
    open = claude_open,
    simple_toggle = claude_open,
    focus_toggle = claude_open,
    close = function()
      local buf = claude_buf()
      if buf then api.nvim_buf_delete(buf, { force = true }) end
    end,
    get_active_bufnr = function() return (claude_buf()) end,
  }

  -- An agent window behaves like a multiplexer pane: entering it types into the
  -- agent and clears its flag, and it closes when the agent exits.
  api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    group = group,
    callback = function()
      if not vim.b.mux_agent then return end
      if vim.b.mux_state then
        vim.b.mux_state = nil
        vim.cmd("redrawtabline")
      end
      vim.cmd("startinsert")
    end,
  })
  api.nvim_create_autocmd("TermClose", {
    group = group,
    callback = function(args)
      if not vim.b[args.buf].mux_agent then return end
      vim.schedule(function()
        if api.nvim_buf_is_valid(args.buf) then api.nvim_buf_delete(args.buf, { force = true }) end
      end)
    end,
  })
  api.nvim_create_autocmd({ "VimResized", "UIEnter" }, {
    group = group,
    callback = function()
      for _, tab in ipairs(api.nvim_list_tabpages()) do fit(tab) end
    end,
  })

  -- <M-a> matches herdr's alt+a. The rest is discoverable under <leader>m.
  local map = vim.keymap.set
  map({ "n", "t" }, "<M-a>", M.jump, { desc = "Agent waiting for input" })
  map("n", "<leader>mw", M.jump, { desc = "Agent waiting for input" })
  map("n", "<leader>mp", M.projects, { desc = "Pick project tab" })
  map("n", "<leader>mt", "<Cmd>belowright split | terminal<CR>i", { desc = "Shell below" })
  map("n", "<leader>md", "<Cmd>detach<CR>", { desc = "Detach (server keeps running)" })
  map("n", "<leader>mk", "<Cmd>Telescope keymaps<CR>", { desc = "Search keymaps" })
  api.nvim_create_autocmd("VimEnter", {
    group = group,
    callback = function()
      local ok, wk = pcall(require, "which-key")
      if ok then wk.add({ { "<leader>m", group = "mux" }, { "<leader>a", group = "agents" } }) end
    end,
  })
end
