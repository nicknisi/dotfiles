-- General
----------------------------------------------------------------
local cmd = vim.cmd
-- abbreviations / common spelling fixes
cmd([[abbr funciton function]])
cmd([[abbr teh the]])
cmd([[abbr tempalte template]])
cmd([[abbr fitler filter]])
cmd([[abbr cosnt const]])
cmd([[abbr attribtue attribute]])
cmd([[abbr attribuet attribute]])

-- Options
-----------------------------------------------------------------

local opt = vim.opt

if not vim.env.SSH_TTY then
  -- don't set the clipboard when in SSH
  opt.clipboard = "unnamedplus" -- use the system clipboard
end

opt.conceallevel = 2 -- concealeed text is hidden

opt.confirm = true -- confirm changes before exiting a buffer
opt.autowrite = true -- enable auto-write
opt.backup = false -- don't use backup files
opt.writebackup = false -- don't backup the file while editing
opt.swapfile = false -- don't create swap files for new buffers

opt.textwidth = 120 -- after configured number of characters, wrap line

opt.mouse = "a" -- set mouse mode to all modes

-- searching
opt.ignorecase = true -- case insensitive searching
opt.smartcase = true -- case-sensitive if expresson contains a capital letter

if vim.fn.executable("rg") == 1 then
  -- if ripgrep installed, use that as a grepper
  opt.grepprg = "rg --vimgrep --no-heading"
  -- create autocmd to automatically open quickfix window when grepping
  vim.cmd([[autocmd QuickFixCmdPost [^l]* nested cwindow]])
end
opt.grepformat = "%f:%l:%c:%m"

-- error bells
opt.visualbell = true
opt.timeoutlen = 300

-- Appearance
---------------------------------------------------------
opt.termguicolors = true
opt.cursorline = true -- enable cursor line highlighting
opt.cursorlineopt = "number" -- highlight only the line number, not the whole line

opt.relativenumber = false
opt.number = true

opt.winborder = "rounded"
opt.wrap = true -- turn on line wrapping
opt.wrapmargin = 8 -- wrap lines when coming within n characters from side
opt.linebreak = true -- set soft wrapping
opt.showbreak = "↪"
opt.diffopt:append({ "vertical", "iwhite", "internal", "algorithm:patience", "hiddenoff" })
opt.laststatus = 3 -- show the global statusline all the time
opt.scrolloff = 7 -- set 7 lines to the cursors - when moving vertical
opt.showmode = false -- don't show which mode
opt.wildmode = { "list", "longest" } -- complete files like a shell
opt.cmdheight = vim.g.vscode and 1 or 0
opt.title = true -- set terminal title
opt.showmatch = true -- show matching braces
opt.updatetime = 200 -- save swap file
opt.signcolumn = "yes" -- show the sign column
opt.shortmess = "atToOFc" -- prompt message options
opt.sidescrolloff = 8

-- Tab control
opt.expandtab = true -- use spaces intead of tabs
opt.tabstop = 2 -- the visible width of tabs
opt.softtabstop = 2 -- edit as if the tabs are 4 characters wide
opt.shiftwidth = 2 -- number of spaces to use for indent and unindent
opt.shiftround = true -- round indent to a multiple of 'shiftwidth'

-- code folding settings
opt.foldmethod = "expr"
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
opt.foldlevelstart = 99
opt.foldnestmax = 10 -- deepest fold is 10 levels
opt.foldenable = false -- don't fold by default
opt.foldlevel = 99
vim.opt.foldcolumn = "0"

vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking text",
  group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

opt.virtualedit = "block"

opt.fillchars = {
  foldopen = "",
  foldclose = "",
  fold = " ",
  foldsep = " ",
  diff = "╱",
  eob = " ",
}

opt.undofile = true

-- toggle invisible characters
opt.list = true
opt.listchars = {
  -- tab = "→ ",
  tab = "  ",
  -- eol = "¬",
  trail = "⋅",
  extends = "❯",
  precedes = "❮",
}
