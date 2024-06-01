local fn = vim.fn
local env = vim.env
local config = require("nisi").config

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

opt.completeopt = { "menu", "menuone", "noselect" }
opt.conceallevel = 2 -- concealeed text is hidden

opt.confirm = true -- confirm changes before exiting a buffer
opt.autowrite = true -- enable auto-write
opt.backup = false -- don't use backup files
opt.writebackup = false -- don't backup the file while editing
opt.swapfile = false -- don't create swap files for new buffers
opt.updatecount = 0 -- don't write swap files after some number of updates
opt.backupdir = { "~/.vim-tmp", "~/.tmp", "~/tmp", "/var/tmp", "/tmp" }
opt.directory = { "~/.vim-tmp", "~/.tmp", "~/tmp", "/var/tmp", "/tmp" }

opt.history = 1000 -- store the last 1000 commands entered
opt.textwidth = 120 -- after configured number of characters, wrap line

-- show the results of substition as they're happening but don't open a split
opt.inccommand = "nosplit"

opt.backspace = { "indent", "eol,start" } -- make backspace behave in a sane manner
opt.mouse = "a" -- set mouse mode to all modes

-- searching
opt.ignorecase = true -- case insensitive searching
opt.smartcase = true -- case-sensitive if expresson contains a capital letter
opt.hlsearch = true -- highlight search results
opt.incsearch = true -- set incremental search, like modern browsers
opt.lazyredraw = false -- don't redraw while executing macros
opt.magic = true -- set magic on, for regular expressions

if fn.executable("rg") then
  -- if ripgrep installed, use that as a grepper
  opt.grepprg = "rg --vimgrep --no-heading"
  -- opt.grepformat = "%f:%l:%c:%m,%f:%l:%m"
  opt.grepformat = "%f:%l:%c:%m"
  -- create autocmd to automatically open quickfix window when grepping
  vim.cmd([[autocmd QuickFixCmdPost [^l]* nested cwindow]])
else
  opt.grepformat = "%f:%l:%c:%m"
end

-- error bells
opt.errorbells = false
opt.visualbell = true
opt.timeoutlen = 500

-- Appearance
---------------------------------------------------------
opt.termguicolors = true

if not config.zen then
  -- show absolute numbers in insert mode, relative in normal mode
  opt.relativenumber = true
  opt.number = true
  vim.cmd([[
  augroup numbertoggle
    autocmd!
    autocmd BufEnter,FocusGained,InsertLeave * set relativenumber
    autocmd BufLeave,FocusLost,InsertEnter   * set norelativenumber
  augroup END
]])
end

opt.hidden = true -- allow background buffers
opt.joinspaces = false -- join lines without two spaces
opt.wrap = true -- turn on line wrapping
opt.wrapmargin = 8 -- wrap lines when coming within n characters from side
opt.linebreak = true -- set soft wrapping
opt.showbreak = "↪"
opt.autoindent = true -- automatically set indent of new line
opt.ttyfast = true -- faster redrawing
table.insert(opt.diffopt, "vertical")
table.insert(opt.diffopt, "iwhite")
table.insert(opt.diffopt, "internal")
table.insert(opt.diffopt, "algorithm:patience")
table.insert(opt.diffopt, "hiddenoff")
opt.laststatus = 3 -- show the global statusline all the time
opt.scrolloff = 7 -- set 7 lines to the cursors - when moving vertical
opt.wildmenu = true -- enhanced command line completion
opt.hidden = true -- current buffer can be put into background
opt.showcmd = true -- show incomplete commands
opt.showmode = false -- don't show which mode
opt.wildmode = { "list", "longest" } -- complete files like a shell
opt.shell = env.SHELL
opt.cmdheight = 0 -- hide command bar when not used
opt.title = true -- set terminal title
opt.showmatch = true -- show matching braces
opt.mat = 2 -- how many tenths of a second to blink
opt.updatetime = 200 -- save swap file
opt.signcolumn = "yes" -- show the sign column
opt.shortmess = "atToOFc" -- prompt message options
opt.sidescrolloff = 8

-- Tab control
opt.expandtab = true -- use spaces intead of tabs
opt.smarttab = true -- tab respects 'tabstop', 'shiftwidth', and 'softtabstop'
opt.tabstop = 2 -- the visible width of tabs
opt.softtabstop = 2 -- edit as if the tabs are 4 characters wide
opt.shiftwidth = 2 -- number of spaces to use for indent and unindent
opt.shiftround = true -- round indent to a multiple of 'shiftwidth'

-- code folding settings
opt.foldmethod = "expr"
opt.foldexpr = "nvim_treesitter#foldexpr()"
opt.foldlevelstart = 99
opt.foldnestmax = 10 -- deepest fold is 10 levels
opt.foldenable = false -- don't fold by default
opt.foldlevel = 1

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

-- hide the ~ character on empty lines at the end of the buffer
opt.fcs = "eob: "
