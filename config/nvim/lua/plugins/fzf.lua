local env = vim.env
local g = vim.g
local fn = vim.fn
local api = vim.api
local o = vim.o
local utils = require("utils")
local nmap = utils.nmap
local xmap = utils.xmap
local omap = utils.omap
local imap = utils.imap

if (fn.isdirectory(".git")) then
  nmap("<leader>t", ":GitFiles --cached --others --exclude-standard<cr>")
else
  nmap("<leader>t", ":FZF<cr>")
end

nmap("<leader>s", ":GFiles?<cr>")
nmap("<leader>r", ":Buffers<cr>")
nmap("<leader>e", ":FZF<cr>")

nmap("<leader><tab>", "<plug>(fzf-maps-n)")
xmap("<leader><tab>", "<plug>(fzf-maps-x)")
omap("<leader><tab>", "<plug>(fzf-maps-o)")

-- Insert mode completion
imap("<c-x><c-k>", "<plug>(fzf-complete-word)")
imap("<c-x><c-f>", "<plug>(fzf-complete-path)")
imap("<c-x><c-j>", "<plug>(fzf-complete-file-ag)")
imap("<c-x><c-l>", "<plug>(fzf-complete-line)")

api.nvim_exec(
  [[
command! FZFMru call fzf#run({ 'source':  v:oldfiles, 'sink':    'e', 'options': '-m -x +s', 'down':    '40%'})
command! -bang -nargs=* Find call fzf#vim#grep('rg --column --line-number --no-heading --follow --color=always '.<q-args>.' || true', 1, <bang>0 ? fzf#vim#with_preview('up:60%') : fzf#vim#with_preview('right:50%:hidden', '?'), <bang>0)
command! -bang -nargs=? -complete=dir Files call fzf#vim#files(<q-args>, fzf#vim#with_preview(), <bang>0)
command! -bang -nargs=? -complete=dir GitFiles call fzf#vim#gitfiles(<q-args>, fzf#vim#with_preview(), <bang>0)
]],
  false
)

function FloatingFZF()
  local lines = o.lines
  local columns = o.columns
  local buf = api.nvim_create_buf(true, true)
  local height = fn.float2nr(lines * 0.5)
  local width = fn.float2nr(columns * 0.7)
  local horizontal = fn.float2nr((columns - width) / 2)
  local vertical = 0
  local opts = {
    relative = "editor",
    row = vertical,
    col = horizontal,
    width = width,
    height = height,
    style = "minimal"
  }
  vim.api.nvim_open_win(buf, true, opts)
end

local fzf_opts = {
  env.FZF_DEFAULT_OPTS or "",
  " --layout=reverse",
  ' --pointer=" "',
  " --info=hidden",
  " --border=rounded",
  " --bind å:select-all+accept"
}

env.FZF_DEFAULT_OPTS = table.concat(fzf_opts, "")

g.fzf_preview_window = {"right:50%:hidden", "?"}
g.fzf_layout = {window = "call v:lua.FloatingFZF()"}
