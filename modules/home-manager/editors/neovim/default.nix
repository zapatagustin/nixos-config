{ pkgs, lib, ... }:
let
  luaFile = name: lib.fileContents (./lua + "/${name}");
  # Neovim ships only the en spell file. Build es from the same hunspell dict
  # emacs uses (editors/emacs/default.nix): mkspell reads <in>.aff/.dic from cwd
  # and writes <out>.<encoding>.spl, so this yields es.utf-8.spl.
  spellEs = pkgs.runCommand "nvim-spell-es" { nativeBuildInputs = [ pkgs.neovim-unwrapped ]; } ''
    cp ${pkgs.hunspellDicts.es_AR}/share/hunspell/es_AR.{aff,dic} .
    mkdir -p $out
    HOME=$TMPDIR nvim --headless -c "mkspell! $out/es es_AR" -c "qa!"
    test -s $out/es.utf-8.spl
  '';
in
{
  # on runtimepath via ~/.config/nvim; `zg` additions land next to it as es.utf-8.add
  xdg.configFile."nvim/spell/es.utf-8.spl".source = "${spellEs}/es.utf-8.spl";

  # stylix neovim target is enabled in ../../stylix.nix (central HM instance).
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

      # optional dep for claudecode.nvim (terminal provider)
      {
        plugin = snacks-nvim;
        type = "lua";
        config = ''
          require("snacks").setup({
            terminal = { enabled = true },
            -- disable unused components
            bigfile = { enabled = false },
            dashboard = { enabled = false },
            explorer = { enabled = false },
            indent = { enabled = false },
            input = { enabled = false },
            notifier = { enabled = false },
            picker = { enabled = false },
            quickfile = { enabled = false },
            scope = { enabled = false },
            scroll = { enabled = false },
            statuscolumn = { enabled = false },
            words = { enabled = false },
            zen = { enabled = false },
          })
        '';
      }
      cmp-nvim-lsp
      cmp-buffer
      cmp-path
      cmp_luasnip
      friendly-snippets

      # colorscheme driven by stylix.targets.neovim (enabled in modules/theme/stylix.nix)
      {
        plugin = nvim-treesitter.withAllGrammars;
        type = "lua";
        # main-branch rewrite: no more nvim-treesitter.configs; highlight/indent
        # are enabled per-buffer (parsers preinstalled by nix, start never downloads)
        config = ''
          vim.api.nvim_create_autocmd("FileType", {
            callback = function(args)
              if not pcall(vim.treesitter.start, args.buf) then return end
              -- take over indent only where a query exists; otherwise the
              -- ftplugin's indentexpr stays (orgmode ships its own, no indents.scm)
              local ok, query = pcall(vim.treesitter.query.get, vim.treesitter.get_parser(args.buf):lang(), "indents")
              if ok and query then
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
              { name = "orgmode" },
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
      # org-mode, counterpart of doom's (org +pretty) (editors/emacs/doom/init.el).
      # nixpkgs builds this from luarocks and patches the tree-sitter-org grammar
      # in (luaPackages.orgmode), so nothing compiles at runtime. Same ~/org as
      # doom (doom/modules/lang.el). Completion source self-registers with cmp.
      {
        plugin = orgmode;
        type = "lua";
        config = ''
          require("orgmode").setup({
            org_agenda_files = "~/org/**/*",
            org_default_notes_file = "~/org/todo.org",
            -- +pretty
            org_startup_indented = true,
            org_hide_leading_stars = true,
            org_hide_emphasis_markers = true,
          })
        '';
      }
      # +pretty: headline bullets + background (org-superstar analog). Parses
      # its org query at load, so it must come after orgmode registers the parser.
      {
        plugin = headlines-nvim;
        type = "lua";
        config = ''require("headlines").setup()'';
      }
      # Claude Code Neovim IDE integration
      {
        plugin = claudecode-nvim;
        type = "lua";
        config = ''
          require("claudecode").setup({})
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
