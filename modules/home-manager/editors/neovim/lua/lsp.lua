local lspconfig = require("lspconfig")
local capabilities = require("cmp_nvim_lsp").default_capabilities()

local on_attach = function(_, bufnr)
  local opts = { buffer = bufnr, silent = true }
  vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
  vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
  vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
  vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
  vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
  vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
  vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
end

-- Servers installed via nix (extraPackages). No Mason.
local servers = {
  nixd = {},
  rust_analyzer = {},
  pyright = {},
  ruff = {},
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
  cfg.on_attach = on_attach
  lspconfig[name].setup(cfg)
end
