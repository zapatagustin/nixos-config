{ pkgs, lib, ... }:
let
  luaFile = name: lib.fileContents (./lua + "/${name}");
in
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    # LSP servers + formatters on Neovim's PATH. No Mason.
    extraPackages = with pkgs; [
      # LSP
      nixd
      rust-analyzer
      pyright
      ruff
      typescript-language-server
      vscode-langservers-extracted # eslint, cssls, jsonls, html
      tailwindcss-language-server
      clang-tools # clangd + clang-format
      lua-language-server
      # formatters (conform)
      nixpkgs-fmt
      stylua
      rustfmt
      prettier
      # startup pokemon sprite (lua/pokemon.lua)
      krabby
    ];

    plugins = with pkgs.vimPlugins; [
      # deps, no config
      nvim-web-devicons
      plenary-nvim
      cmp-nvim-lsp
      cmp-buffer
      cmp-path
      cmp_luasnip
      friendly-snippets

      # colorscheme managed by stylix (modules/theme/stylix.nix)
      {
        plugin = nvim-treesitter.withAllGrammars;
        type = "lua";
        # main-branch rewrite: no more nvim-treesitter.configs; highlight/indent
        # are enabled per-buffer (parsers preinstalled by nix, start never downloads)
        config = ''
          vim.api.nvim_create_autocmd("FileType", {
            callback = function(args)
              if pcall(vim.treesitter.start, args.buf) then
                vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
              end
            end,
          })
        '';
      }
      telescope-fzf-native-nvim # built by nix, no :make
      {
        plugin = telescope-nvim;
        type = "lua";
        config = ''
          require("telescope").setup({})
          pcall(require("telescope").load_extension, "fzf")
        '';
      }
      {
        plugin = luasnip;
        type = "lua";
        config = ''require("luasnip.loaders.from_vscode").lazy_load()'';
      }
      {
        plugin = nvim-cmp;
        type = "lua";
        config = ''
          local cmp = require("cmp")
          local luasnip = require("luasnip")
          cmp.setup({
            snippet = { expand = function(args) luasnip.lsp_expand(args.body) end },
            mapping = cmp.mapping.preset.insert({
              ["<C-Space>"] = cmp.mapping.complete(),
              ["<CR>"] = cmp.mapping.confirm({ select = true }),
              ["<Tab>"] = cmp.mapping.select_next_item(),
              ["<S-Tab>"] = cmp.mapping.select_prev_item(),
            }),
            sources = {
              { name = "nvim_lsp" },
              { name = "luasnip" },
              { name = "buffer" },
              { name = "path" },
            },
          })
        '';
      }
      {
        plugin = gitsigns-nvim;
        type = "lua";
        config = ''require("gitsigns").setup()'';
      }
      {
        plugin = lualine-nvim;
        type = "lua";
        config = ''require("lualine").setup({ options = { theme = "auto" } })'';
      }
      {
        plugin = which-key-nvim;
        type = "lua";
        config = ''require("which-key").setup()'';
      }
      {
        plugin = nvim-tree-lua;
        type = "lua";
        config = ''require("nvim-tree").setup()'';
      }
      {
        plugin = oil-nvim;
        type = "lua";
        config = ''require("oil").setup()'';
      }
      {
        plugin = nvim-autopairs;
        type = "lua";
        config = ''require("nvim-autopairs").setup()'';
      }
      {
        plugin = comment-nvim;
        type = "lua";
        config = ''require("Comment").setup()'';
      }
      {
        plugin = nvim-surround;
        type = "lua";
        config = ''require("nvim-surround").setup()'';
      }
      {
        plugin = conform-nvim;
        type = "lua";
        config = ''
          require("conform").setup({
            format_on_save = { timeout_ms = 2000, lsp_format = "fallback" },
            formatters_by_ft = {
              nix = { "nixpkgs_fmt" },
              lua = { "stylua" },
              python = { "ruff_format" },
              rust = { "rustfmt" },
              javascript = { "prettier" },
              typescript = { "prettier" },
              javascriptreact = { "prettier" },
              typescriptreact = { "prettier" },
              css = { "prettier" },
              html = { "prettier" },
              json = { "prettier" },
            },
          })
        '';
      }
      # LSP setup last (servers configured from lua/lsp.lua)
      {
        plugin = nvim-lspconfig;
        type = "lua";
        config = luaFile "lsp.lua";
      }
    ];

    # options + keymaps: no plugin-load-order dependency (command-style maps)
    initLua = ''
      ${luaFile "options.lua"}
      ${luaFile "keymaps.lua"}
      ${luaFile "pokemon.lua"}
    '';
  };
}
