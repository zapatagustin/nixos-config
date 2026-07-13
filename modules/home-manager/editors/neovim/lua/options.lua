vim.g.mapleader = " "
vim.g.maplocalleader = " "

local opt = vim.opt
opt.number = true
opt.relativenumber = true
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true
opt.ignorecase = true
opt.smartcase = true
opt.termguicolors = true
opt.clipboard = "unnamedplus"
opt.undofile = true
opt.swapfile = false
opt.scrolloff = 8
opt.signcolumn = "yes"
opt.wrap = false
opt.splitbelow = true
opt.splitright = true
opt.completeopt = { "menuone", "noselect" }

-- dvorak: normal/visual/operator commands land on QWERTY physical positions;
-- insert mode, cmdline text and telescope prompts stay dvorak (langmap only
-- translates command keys). nolangremap keeps mappings from double-translating.
opt.langremap = false
opt.langmap = {
  -- row 1: ' , . p y f g c r l / =  ->  q w e r t y u i o p [ ]
  "'q", "\\,w", ".e", "pr", "yt", "fy", "gu", "ci", "ro", "lp", "/[", "=]",
  '"Q', "<W", ">E", "PR", "YT", "FY", "GU", "CI", "RO", "LP", "?{", "+}",
  -- row 2: o e u i d h t n s -  ->  s d f g h j k l ; '
  "os", "ed", "uf", "ig", "dh", "hj", "tk", "nl", "s\\;", "-'",
  "OS", "ED", "UF", "IG", "DH", "HJ", "TK", "NL", "S:", '_"',
  -- row 3: ; q j k x b w v z  ->  z x c v b n , . /
  "\\;z", "qx", "jc", "kv", "xb", "bn", "w\\,", "v.", "z/",
  ":Z", "QX", "JC", "KV", "XB", "BN", "W<", "V>", "Z?",
  -- number row tail: [ ] -> - =
  "[-", "]=", "{_", "}+",
}

-- treesitter folding, open by default
opt.foldlevel = 99
opt.foldmethod = "expr"
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
