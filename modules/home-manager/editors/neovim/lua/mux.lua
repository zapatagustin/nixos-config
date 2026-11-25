-- Neovim as the terminal multiplexer. PROTOTYPE, to compare in use with herdr
-- (shells/herdr); nothing here runs in an ordinary nvim.
--
-- Active only in the editor that the `vdev` shell function starts with
-- `--cmd "let g:mux = 1"`: a headless server that terminals attach to with
-- --remote-ui, so the agents keep running after :detach or a closed terminal.
--
-- The agents are the point, not the editor. One tabpage per project (a
-- "space"). Each has the sidebar on the left, which lists every space with its
-- agents and what they are doing, and a stack on the right: it starts as the
-- start screen, and claude, omp and the notes file open in it one above the
-- other, the focused one expanded and the rest folded to their title line.
-- The rest is stock vim: CTRL-W, :split, :q, gt, :tabclose.
if vim.g.mux then
  local api, fn = vim.api, vim.fn
  local M = { st = {}, rows = {} }
  _G.Mux = M
  local group = api.nvim_create_augroup("mux", {})
  local function now() return vim.uv.hrtime() / 1e6 end

  -- The stack: 'winheight' makes the focused window take the column and
  -- 'winminheight' lets the others fold down to their status line. A folded
  -- terminal keeps its size, so its agent is not redrawn (verified).
  vim.o.winminheight = 0
  vim.o.winheight = 999
  vim.o.showtabline = 0 -- the sidebar is the list of spaces

  M.side = api.nvim_create_buf(false, true)
  api.nvim_buf_set_name(M.side, "agents")
  vim.bo[M.side].filetype = "mux"

  -- Windows of a tabpage's stack: everything but the sidebar and floats.
  local function stack_wins(tab)
    return vim.tbl_filter(function(w)
      return api.nvim_win_get_buf(w) ~= M.side and api.nvim_win_get_config(w).relative == ""
    end, api.nvim_tabpage_list_wins(tab))
  end
  local function space_tab(dir)
    for _, tab in ipairs(api.nvim_list_tabpages()) do
      if vim.t[tab].mux_dir == dir then return tab end
    end
  end
  local function start_screen()
    return M.dash and api.nvim_buf_is_valid(M.dash) and M.dash or api.nvim_create_buf(true, false)
  end

  -- Puts the cursor in the stack window the next item goes in: the start screen
  -- (or an unused empty buffer) is replaced, anything else gets a window below.
  local function place()
    local wins = stack_wins(0)
    api.nvim_set_current_win(wins[#wins])
    local buf = api.nvim_get_current_buf()
    local unused = fn.bufname(buf) == "" and vim.bo[buf].buftype == "" and not vim.bo[buf].modified
    if #wins > 1 or not (buf == M.dash or unused) then
      vim.cmd("belowright new")
    elseif buf == M.dash then
      vim.cmd("enew")
    end
  end

  -- What the sidebar shows for an agent. "blocked" and an immediate "done" come
  -- from the agent itself (M.signal). The rest is read off its terminal, so it
  -- works for any agent: output in the last seconds is "working", and one that
  -- went quiet while you were elsewhere is "done" until you visit it.
  -- ecomono: an agent that animates while idle reads as "working" forever.
  -- Upgrade: per-agent screen patterns, as herdr's detection manifests do.
  local QUIET = 3000
  function M.status(buf)
    local s = M.st[buf]
    if not s then return "" end
    if s.state == "blocked" then return "blocked" end
    if now() - s.out < QUIET then return "working" end
    return (s.state == "done" or s.unseen) and "done" or "idle"
  end

  local function render()
    local lines, rows, cur = {}, {}, api.nvim_get_current_tabpage()
    for i, tab in ipairs(api.nvim_list_tabpages()) do
      local dir = vim.t[tab].mux_dir
      if dir then
        lines[#lines + 1] = (tab == cur and ">" or " ") .. i .. " " .. vim.fs.basename(dir)
        rows[#lines] = { tab = tab }
        for _, buf in ipairs(api.nvim_list_bufs()) do
          if M.st[buf] and M.st[buf].dir == dir then
            lines[#lines + 1] = string.format("   %-8s %s", M.st[buf].name, M.status(buf))
            rows[#lines] = { buf = buf }
          end
        end
      end
    end
    vim.list_extend(lines, { "", " c claude   o omp", " n notes    t shell" })
    M.rows = rows
    if table.concat(lines, "\n") ~= table.concat(api.nvim_buf_get_lines(M.side, 0, -1, false), "\n") then
      vim.bo[M.side].modifiable = true
      api.nvim_buf_set_lines(M.side, 0, -1, false, lines)
      vim.bo[M.side].modifiable = false
    end
  end
  M.render = render
  -- Statuses change with time (working -> done), not only with events.
  M.timer = vim.uv.new_timer()
  M.timer:start(1000, 1000, vim.schedule_wrap(render))
  api.nvim_buf_call(M.side, function()
    vim.cmd([[
      syntax match MuxSpace /^.\d\+ .*/
      syntax match MuxBlocked /blocked$/
      syntax match MuxDone /done$/
      syntax match MuxWorking /working$/
      syntax match MuxIdle /idle$/
      syntax match MuxIdle /^ \a \a\+ \+\a \a\+$/
      highlight default link MuxSpace Title
      highlight default link MuxBlocked DiagnosticWarn
      highlight default link MuxDone DiagnosticOk
      highlight default link MuxWorking DiagnosticInfo
      highlight default link MuxIdle Comment
    ]])
  end)

  -- Goes to an agent: its window if it has one, else a new one in its space.
  local function focus(buf)
    local win = fn.win_findbuf(buf)[1]
    if win then return api.nvim_set_current_win(win) end -- also switches tabpage
    local tab = space_tab(M.st[buf].dir)
    if tab then api.nvim_set_current_tabpage(tab) end
    place()
    api.nvim_set_current_buf(buf)
  end

  -- Starts `cmd` as an agent of the current space, in the stack, and returns
  -- its buffer. $MUX_BUF tells the agent's hooks which buffer to flag (M.signal).
  function M.agent(name, cmd, env)
    place()
    local buf = api.nvim_get_current_buf()
    local dir = vim.t.mux_dir or fn.getcwd(-1, 0)
    local s = { name = name, dir = dir, out = 0 }
    M.st[buf] = s
    -- The size its program was last drawn at. A folded window keeps its
    -- height, so only its width counts then.
    local function size()
      local win = fn.win_findbuf(buf)[1]
      if not win then return s.size end
      local height = api.nvim_win_get_height(win)
      if height > 0 then s.height = height end
      return api.nvim_win_get_width(win) * 10000 + (s.height or 0)
    end
    s.size = size()
    fn.jobstart(cmd, {
      term = true,
      cwd = fn.getcwd(-1, 0),
      env = vim.tbl_extend("force", env or {}, { MUX_BUF = tostring(buf) }),
      -- The program's own output (unlike on_lines, not nvim reflowing the
      -- buffer) is the activity the sidebar reports.
      on_stdout = function()
        if M.st[buf] ~= s then return end
        -- A program redraws when its window changes size: that is not activity.
        if size() ~= s.size then s.size, s.resized = size(), now() end
        if now() - (s.resized or 0) < 1000 then return end
        s.out = now()
        if api.nvim_get_current_buf() ~= buf and not s.unseen then s.unseen, s.since = true, s.since or now() end
      end,
    })
    -- The folded window's status line is the item's title.
    local title = name .. " " .. vim.fs.basename(dir)
    if not pcall(api.nvim_buf_set_name, buf, title) then pcall(api.nvim_buf_set_name, buf, title .. " #" .. buf) end
    vim.cmd("startinsert")
    render()
    return buf
  end

  -- Called by an agent through $NVIM (claude-notify in ../../ai): "blocked" =
  -- needs an answer now, "done" = its turn finished. Returns a number because
  -- --remote-expr prints the result.
  function M.signal(buf, state)
    local s = M.st[buf]
    if not s then return 0 end
    -- No flag for the agent that is being looked at.
    if buf == api.nvim_get_current_buf() and #api.nvim_list_uis() > 0 then return 0 end
    s.state, s.since = state, now()
    if state == "done" then s.out = 0 end -- finished: do not wait for it to go quiet
    render()
    return 1
  end

  -- Goes to the agent that has waited longest, blocked ones before finished ones.
  function M.jump()
    local best, best_rank
    for buf, s in pairs(M.st) do
      local status = M.status(buf)
      if status == "blocked" or status == "done" then
        local rank = (status == "blocked" and 0 or 1e15) + (s.since or 0)
        if not best_rank or rank < best_rank then best, best_rank = buf, rank end
      end
    end
    if not best then return vim.notify("mux: no agent is waiting") end
    focus(best)
  end

  -- The notes file of the current space, in the stack.
  -- ecomono: one fixed name per space. Upgrade: vim.g.mux_notes per project.
  function M.notes()
    local file = fn.fnamemodify(vim.g.mux_notes or "todo.md", ":p")
    local win = fn.win_findbuf(fn.bufnr(file))[1]
    if win and api.nvim_win_get_tabpage(win) == api.nvim_get_current_tabpage() then
      api.nvim_set_current_win(win)
    else
      place()
      vim.cmd("edit " .. fn.fnameescape(file))
    end
    vim.cmd("stopinsert")
  end

  function M.shell()
    place()
    vim.cmd("terminal")
    vim.cmd("startinsert")
  end

  function M.sidebar()
    local win = vim.tbl_filter(function(w) return api.nvim_win_get_buf(w) == M.side end, api.nvim_tabpage_list_wins(0))[1]
    if win then return api.nvim_set_current_win(win) end
    vim.cmd("topleft vertical 28 split")
    api.nvim_win_set_buf(0, M.side)
    for name, value in pairs({ winfixwidth = true, number = false, relativenumber = false, signcolumn = "no", wrap = false, cursorline = true }) do
      api.nvim_set_option_value(name, value, { win = 0, scope = "local" })
    end
    vim.cmd("stopinsert")
  end

  -- Entry point of `vdev`, through --remote-expr: the space of project `dir`,
  -- created if missing. `spec` (letters c o v, optional) opens claude, omp and
  -- the notes right away; without it the space starts on the start screen.
  function M.open(dir, spec)
    spec = spec or ""
    if not spec:match("^[vco]*$") then error("vdev: bad SPEC '" .. spec .. "' (letters v c o)") end
    local tab = space_tab(dir)
    if tab then
      api.nvim_set_current_tabpage(tab)
    else
      if next(vim.tbl_filter(function(t) return vim.t[t].mux_dir ~= nil end, api.nvim_list_tabpages())) then
        vim.cmd("tabnew")
        if M.dash and api.nvim_buf_is_valid(M.dash) then api.nvim_set_current_buf(M.dash) end
      elseif vim.bo.buftype == "terminal" then
        -- A new server: its one tab shows the start screen (lua/pokemon.lua).
        M.dash = api.nvim_get_current_buf()
        M.launchers(M.dash)
      end
      vim.cmd("tcd " .. fn.fnameescape(dir))
      vim.t.mux_dir = dir
      M.sidebar()
      vim.cmd("wincmd p")
    end
    if spec:find("c") then vim.cmd("ClaudeCode") end
    if spec:find("o") then M.agent("omp", "omp") end
    if spec:find("v") then M.notes() end
    render()
    return 1
  end

  -- claudecode.nvim terminal provider (see its entry in default.nix): claude in
  -- the stack of the current space instead of a herdr pane.
  -- ecomono: one claude per space, so a second :ClaudeCode there only focuses
  -- the first and `:ClaudeCode --resume` needs it closed first. Selections are
  -- broadcast to every claude of this editor, whatever its space. Upgrade:
  -- several per space keyed by the command string; one editor per project.
  local function claude_buf()
    for buf, s in pairs(M.st) do
      if s.name == "claude" and s.dir == vim.t.mux_dir then return buf end
    end
  end
  local function claude_open(cmd, env, _, focused)
    local prev = api.nvim_get_current_win()
    local buf = claude_buf()
    if buf then focus(buf) else M.agent("claude", cmd, env) end
    if focused == false then
      api.nvim_set_current_win(prev)
      if not M.st[api.nvim_get_current_buf()] then vim.cmd("stopinsert") end
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
    get_active_bufnr = claude_buf,
  }

  -- Visiting an agent types into it and marks it seen.
  api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
    group = group,
    callback = function()
      local s = M.st[api.nvim_get_current_buf()]
      if not s then return end
      s.state, s.unseen, s.since = nil, false, nil
      vim.cmd("startinsert")
      render()
    end,
  })
  api.nvim_create_autocmd({ "TabEnter", "TabClosed" }, { group = group, callback = vim.schedule_wrap(render) })
  -- An agent that exits takes its window with it; the stack never empties.
  api.nvim_create_autocmd("TermClose", {
    group = group,
    callback = function(args)
      if not M.st[args.buf] then return end
      M.st[args.buf] = nil
      vim.schedule(function()
        if not api.nvim_buf_is_valid(args.buf) then return end
        for _, win in ipairs(fn.win_findbuf(args.buf)) do
          if #stack_wins(api.nvim_win_get_tabpage(win)) == 1 then api.nvim_win_set_buf(win, start_screen()) end
        end
        api.nvim_buf_delete(args.buf, { force = true })
        render()
      end)
    end,
  })

  -- <M-a> matches herdr's alt+a. The rest is discoverable under <leader>m, and
  -- the start screen and the sidebar take the launchers as single keys.
  local map = vim.keymap.set
  function M.launchers(buf)
    map("n", "c", "<Cmd>ClaudeCode<CR>", { buffer = buf, desc = "Claude" })
    map("n", "o", "<Cmd>OmpPane<CR>", { buffer = buf, desc = "omp" })
    map("n", "n", M.notes, { buffer = buf, desc = "Notes" })
    map("n", "t", M.shell, { buffer = buf, desc = "Shell" })
  end
  M.launchers(M.side)
  map("n", "<CR>", function()
    local row = M.rows[fn.line(".")]
    if not row then return end
    if row.buf then focus(row.buf) else api.nvim_set_current_tabpage(row.tab) end
  end, { buffer = M.side, desc = "Go to space or agent" })
  map({ "n", "t" }, "<M-a>", M.jump, { desc = "Agent waiting for input" })
  map("n", "<leader>mw", M.jump, { desc = "Agent waiting for input" })
  map("n", "<leader>ms", M.sidebar, { desc = "Sidebar: spaces and agents" })
  map("n", "<leader>mn", M.notes, { desc = "Notes" })
  map("n", "<leader>mt", M.shell, { desc = "Shell" })
  map("n", "<leader>mz", function()
    vim.o.winheight = vim.o.winheight == 999 and 1 or 999
    if vim.o.winheight == 1 then vim.cmd("wincmd =") end
  end, { desc = "Stack: folded / equal heights" })
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
