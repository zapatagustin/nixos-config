# Neovim nix-native — Design

**Date:** 2026-06-22
**Status:** Approved (design), pending implementation

## Goal

Replace the deleted imperative neovim config (lazy.nvim + Mason) with a
declarative, nix-managed Neovim. Reproducible, no runtime plugin/LSP downloads,
consistent with the rest of this flake. Scope: **lean** editor, not full IDE.

## Non-goals (YAGNI — add later if needed)

DAP/debugging, neotest, toggleterm (`:terminal` builtin covers it), harpoon,
indent-blankline, copilot.

## Mechanism

- `programs.neovim` (home-manager). Plugins from `pkgs.vimPlugins` — nix pins them.
- **No** `lazy.nvim` bootstrap, **no** Mason.
- LSP servers installed via `extraPackages` (on Neovim's PATH only), configured
  with `nvim-lspconfig` directly.
- Treesitter via `nvim-treesitter.withAllGrammars` — grammars built by nix, no
  `:TSInstall`, no network at runtime.

## Structure (modular)

```
modules/home-manager/editors/
  neovim/
    default.nix     # programs.neovim: enable, aliases, extraPackages (LSPs),
                    # plugins list, sources the lua files
    lua/
      options.lua   # vim options (ported from old options.lua, trimmed)
      keymaps.lua   # essential mappings
      lsp.lua       # nvim-lspconfig server setup + on_attach keymaps
```

- `default.nix` builds the plugin list. Plugins needing setup get inline lua via
  `{ plugin = ...; type = "lua"; config = ''...''; }`.
- `options.lua` / `keymaps.lua` / `lsp.lua` are sourced into `extraLuaConfig`
  using `lib.fileContents` (real `.lua` files → editor highlighting, small files).
- Wired into `modules/home-manager/home.nix` imports (was orphaned before).

## Plugins (~13)

| Plugin | Purpose | Has config |
|---|---|---|
| nvim-treesitter.withAllGrammars | syntax/highlight/fold | yes |
| telescope-nvim (+ telescope-fzf-native, plenary) | find/grep | yes |
| nvim-lspconfig | LSP | yes (lsp.lua) |
| nvim-cmp (+ cmp-nvim-lsp, cmp-buffer, cmp-path, luasnip, cmp_luasnip) | completion | yes |
| gitsigns-nvim | git gutter | yes |
| lualine-nvim | statusline | yes |
| which-key-nvim | keybind hints | yes |
| nvim-tree-lua | file explorer (sidebar) | yes |
| oil-nvim | file explorer (buffer/parent-dir, `-`) | yes |
| nvim-autopairs | autopairs | yes |
| comment-nvim | commenting | yes |
| nvim-surround | surround | yes |
| conform-nvim | format-on-save | yes |
| nvim-web-devicons | icons | no |
| gruvbox-nvim | colorscheme | yes (`vim.cmd.colorscheme "gruvbox"`) |

Both nvim-tree (sidebar, `<leader>e`) and oil (edit-dir-as-buffer, `-`) included
by request — they cover different workflows.

## LSP / formatters (via nix, in extraPackages)

| Language | Server (lspconfig name) | Package | Format |
|---|---|---|---|
| Nix | nixd | nixd | nixpkgs-fmt |
| Rust | rust_analyzer | rust-analyzer | rustfmt (via RA) |
| Python | pyright + ruff | pyright, ruff | ruff |
| JS/TS | ts_ls | typescript-language-server | eslint LSP |
| ESLint/CSS/JSON/HTML | eslint, cssls, jsonls, html | vscode-langservers-extracted | cssls |
| Tailwind | tailwindcss | tailwindcss-language-server | — |
| C | clangd | clang-tools | clangd |
| Lua | lua_ls | lua-language-server | stylua |

Formatting: **conform.nvim** with `format_on_save` (`lsp_fallback = true`).
Formatters by filetype: nixpkgs_fmt (nix), stylua (lua), ruff_format (python),
rustfmt (rust), prettier (js/ts/css/html/json), clang-format via lsp_fallback (c).

## Keymaps (MINIMAL — full revision deferred to a later session)

Global (leader = space):

| Key | Action |
|---|---|
| `<leader>ff` / `<leader>fg` / `<leader>fb` | telescope find files / live grep / buffers |
| `<leader>e` | nvim-tree toggle |
| `-` | oil (parent dir) |

LSP (buffer-local, set in `on_attach`): `gd` `gr` `K` `<leader>rn` `<leader>ca` `[d` `]d`.

Ported `vim.opt` essentials from the old `options.lua`: relativenumber, termguicolors,
clipboard=unnamedplus, expandtab/shiftwidth=2, smartcase, undofile, scrolloff=8,
treesitter folding (foldlevel=99).

## Verification

- Local: `nix-instantiate --parse` on each `.nix` (temp store on this machine,
  no real `/nix/store`).
- Real eval/build: on the thinkpad via `nixos-rebuild switch`. First launch:
  treesitter grammars already present; LSP servers on PATH; `:checkhealth` to confirm.

## Risks

- `tailwindcss-language-server` attaches only in projects with tailwind config — expected.
- `lua_ls` may warn about vim globals → configure `Lua.diagnostics.globals = ["vim"]` in lsp.lua.
