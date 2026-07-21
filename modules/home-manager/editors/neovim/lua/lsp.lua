-- nvim 0.11+ native API; nvim-lspconfig is data-only (provides lsp/*.lua defs)
local capabilities = require("cmp_nvim_lsp").default_capabilities()

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local opts = { buffer = args.buf, silent = true }
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
    vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
    vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
    vim.keymap.set("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, opts)
    vim.keymap.set("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, opts)
  end,
})

-- Servers installed via nix (extraPackages). No Mason.
local servers = {
  nixd = {},
  rust_analyzer = {},
  pyright = {},
  -- ruff handles lint/format; let pyright own hover to avoid duplicate popups
  ruff = {
    on_attach = function(client)
      client.server_capabilities.hoverProvider = false
    end,
  },
  ts_ls = {},
  eslint = {},
  cssls = {},
  jsonls = {},
  html = {},
  tailwindcss = {},
  clangd = {},
  lua_ls = {
    settings = { Lua = { diagnostics = { globals = { "vim" } } } },
  },
}

for name, cfg in pairs(servers) do
  cfg.capabilities = capabilities
  vim.lsp.config(name, cfg)
  vim.lsp.enable(name)
end
