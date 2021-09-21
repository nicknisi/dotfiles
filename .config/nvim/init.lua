local g   = vim.g   -- global variables
local o   = vim.o   -- global options
local b   = vim.bo  -- buffer-scoped options
local opt = vim.opt -- to set options

opt.syntax         = 'off'
opt.showtabline    = 2
opt.ruler          = true -- show line,col at the cursor pos
opt.number         = true -- show absolute line no. at the cursor pos
opt.relativenumber = true -- otherwise, show relative numbers in the ruler
opt.cursorline     = true -- Show a line where the current cursor is
opt.signcolumn     = "yes"

opt.updatetime     = 100
opt.shortmess      = "scWFI"
opt.autoread       = true
opt.autowrite      = true
opt.timeoutlen     = 1000
opt.ttimeoutlen    = 0
opt.cindent        = true
opt.backspace      = "indent,eol,start"
opt.wrap           = false
opt.formatoptions  = opt.formatoptions
    - "a" -- Auto formatting is BAD.
    - "t" -- Don't auto format my code. I got linters for that.
    + "c" -- In general, I like it when comments respect textwidth
    + "q" -- Allow formatting comments w/ gq
    - "o" -- O and o, don't continue comments
    + "r" -- But do continue when pressing enter.
    + "n" -- Indent past the formatlistpat, not underneath it.
    + "j" -- Auto-remove comments if possible.
    - "2" -- I'm not in gradeschool anymore
opt.eb             = false
opt.vb             = true
opt.mouse          = "a"
opt.sidescrolloff  = 30
opt.eol            = false
opt.splitright     = true
opt.list           = true
opt.listchars = {
    eol = "↴",
    tab = "▏ ",
    trail = "·",
    extends = "→",
}
opt.termguicolors = true

o.showmatch      = true      -- highlight matching [{()}]
o.showcmd        = true      -- show current command under the cmd line
o.showmode       = true      -- show current mode (insert, etc) under the cmdline
o.undofile       = false
o.autochdir      = false
o.cmdheight      = 2         -- cmdline height
o.laststatus     = 2         -- 2 = always show status line (filename, etc)
o.breakindent    = true      -- start wrapped lines indented
o.linebreak      = true      -- do not break words on line wrap
o.completeopt    = "menu,menuone,noinsert"

o.wildmenu       = true
o.wildmode       = "longest:full,full"
o.wildoptions    = "pum"     -- Show completion items using the pop-up-menu (pum)

o.pumblend       = 30        -- Give the pum some transparency
o.backup         = false     -- no backup file
o.writebackup    = false     -- do not backup file before write
o.swapfile       = false     -- no swap file
o.wb             = false
o.smartindent    = true      -- add <tab> depending on syntax (C/C++)
o.smarttab       = true
b.autoindent     = true
o.tabstop        = 4         -- Tab indentation levels every two columns
o.softtabstop    = 4         -- Tab indentation when mixing tabs & spaces
o.shiftwidth     = 4         -- Indent/outdent by two columns
o.shiftround     = true      -- Always indent/outdent to nearest tabstop
o.expandtab      = true      -- Convert all tabs that are typed into spaces
o.smarttab       = true      -- Use shiftwidths at left margin, tabstops everywhere else
o.magic          = true      -- use 'magic' chars in search patterns
o.hlsearch       = true      -- highlight all text matching current search pattern
o.incsearch      = true      -- show search matches as you type
o.ignorecase     = true      -- ignore case on search
o.smartcase      = true      -- case sensitive when search includes uppercase
o.inccommand     = "nosplit" -- show search and replace in real time
o.autoread       = true      -- reread a file if it's changed outside of vim
o.wrapscan       = true      -- begin search from top of the file when nothng is found

o.foldenable     = false     -- enable folding
o.foldlevelstart = 10        -- open most folds by default
o.foldnestmax    = 10        -- 10 nested fold max
o.foldmethod     = 'indent'  -- fold based on indent level


-- Disable providers we do not care a about
g.loaded_python_provider = 0
g.loaded_ruby_provider   = 0
g.loaded_perl_provider   = 0
g.loaded_node_provider   = 0

-- Disable some in built plugins completely
local disabled_built_ins = {
    "netrw",
    "netrwPlugin",
    "netrwSettings",
    "netrwFileHandlers",
    "gzip",
    "zip",
    "zipPlugin",
    "tar",
    "tarPlugin",
    "getscript",
    "getscriptPlugin",
    "vimball",
    "vimballPlugin",
    "2html_plugin",
    "logipat",
    "rrhelper",
    "spellfile_plugin",
    "matchit",
}
for _, plugin in pairs(disabled_built_ins) do
    vim.g["loaded_" .. plugin] = 1
end

function _G.dump(...)
    local objects = vim.tbl_map(vim.inspect, { ... })
    print(unpack(objects))
end

require("statusline")
require("tabline")
require("keymaps")
require("autocmd")
require("plugins")
require("go.tags")
