local cmd = vim.cmd -- execute Vim commands
local g = vim.g -- global variables
local o = vim.o -- global options
local b = vim.bo -- buffer-scoped options
local opt = vim.opt -- to set options

opt.syntax = 'on'

o.undofile = false
opt.hidden = true
o.autochdir = false

o.showmode = true -- show current mode (insert, etc) under the cmdline
o.showcmd = true -- show current command under the cmd line
opt.showtabline = 2
o.cmdheight = 2 -- cmdline height
o.laststatus = 2 -- 2 = always show status line (filename, etc)
opt.ruler = true
opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.signcolumn = 'yes'
o.wrap = true -- wrap long lines
o.breakindent = true -- start wrapped lines indented
o.linebreak = true -- do not break words on line wrap

opt.list = true
cmd [[
set listchars=tab:┆\ 
set listchars+=eol:¬
set listchars+=trail:·,extends:→
]]

o.completeopt = 'noinsert,menuone,noselect'
opt.wildmenu = true
opt.wildmode = 'longest:full,full'
o.wildoptions = 'pum' -- Show completion items using the pop-up-menu (pum)
o.pumblend = 30 -- Give the pum some transparency

opt.updatetime = 100
opt.shortmess = 'c'
opt.autoread = true
opt.autowrite = true
opt.showmatch = true
opt.timeoutlen = 1000
opt.ttimeoutlen = 0
o.backup = false -- no backup file
o.writebackup = false -- do not backup file before write
o.swapfile = false -- no swap file

o.wb = false

o.smartindent = true -- add <tab> depending on syntax (C/C++)
o.smarttab = true
b.autoindent = true
opt.cindent = true

o.tabstop = 4 -- Tab indentation levels every two columns
o.softtabstop = 4 -- Tab indentation when mixing tabs & spaces
o.shiftwidth = 4 -- Indent/outdent by two columns
o.shiftround = true -- Always indent/outdent to nearest tabstop
o.expandtab = true -- Convert all tabs that are typed into spaces
o.smarttab = true -- Use shiftwidths at left margin, tabstops everywhere else

o.magic = true --  use 'magic' chars in search patterns
o.hlsearch = true -- highlight all text matching current search pattern
o.incsearch = true -- show search matches as you type
o.ignorecase = true -- ignore case on search
o.smartcase = true -- case sensitive when search includes uppercase
o.showmatch = true -- highlight matching [{()}]
o.inccommand = 'nosplit' -- show search and replace in real time
o.autoread = true -- reread a file if it's changed outside of vim
o.wrapscan = true -- begin search from top of the file when nothng is found
o.cpoptions = vim.o.cpoptions .. 'x' -- stay at seach item when <esc>

opt.backspace = 'indent,eol,start'
opt.wrap = false
-- LuaFormatter off
opt.formatoptions = opt.formatoptions
  - "a" -- Auto formatting is BAD.
  - "t" -- Don't auto format my code. I got linters for that.
  + "c" -- In general, I like it when comments respect textwidth
  + "q" -- Allow formatting comments w/ gq
  - "o" -- O and o, don't continue comments
  + "r" -- But do continue when pressing enter.
  + "n" -- Indent past the formatlistpat, not underneath it.
  + "j" -- Auto-remove comments if possible.
  - "2" -- I'm not in gradeschool anymore
-- LuaFormatter on
opt.eb = false
opt.vb = true
opt.mouse = 'a'
opt.sidescrolloff = 30
opt.eol = false
opt.termguicolors = true
opt.background = 'dark'

g.gruvbox_flat_style = 'dark'
cmd 'colorscheme gruvbox-flat'

-- Disable providers we do not care a about
g.loaded_python_provider = 0
g.loaded_ruby_provider = 0
g.loaded_perl_provider = 0
g.loaded_node_provider = 0

-- Disable some in built plugins completely
local disabled_built_ins = {
    'netrw', 'netrwPlugin', 'netrwSettings', 'netrwFileHandlers', 'gzip', 'zip',
    'zipPlugin', 'tar', 'tarPlugin', 'getscript', 'getscriptPlugin', 'vimball',
    'vimballPlugin', '2html_plugin', 'logipat', 'rrhelper', 'spellfile_plugin'
}
for _, plugin in pairs(disabled_built_ins) do vim.g['loaded_' .. plugin] = 1 end

function _G.dump(...)
    local objects = vim.tbl_map(vim.inspect, {...})
    print(unpack(objects))
end

require('statusline')
require('tabline')
require('keymaps')
require('autocmd')

require('lsp')
require('plugin')
require('plugins')
