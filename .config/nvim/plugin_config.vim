
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Plugins Config:
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

"{{{
let g:nvim_tree_side = 'left' "left by default
let g:nvim_tree_width = 40 "30 by default
let g:nvim_tree_ignore = [ '.git', 'node_modules', '.cache' ] "empty by default
let g:nvim_tree_gitignore = 1 "0 by default
let g:nvim_tree_auto_open = 0 "0 by default, opens the tree when typing `vim $DIR` or `vim`
let g:nvim_tree_auto_close = 1 "0 by default, closes the tree when it's the last window
let g:nvim_tree_auto_ignore_ft = [ 'startify', 'dashboard' ] "empty by default, don't auto open tree on specific filetypes.
let g:nvim_tree_quit_on_open = 1 "0 by default, closes the tree when you open a file
let g:nvim_tree_follow = 1 "0 by default, this option allows the cursor to be updated when entering a buffer
let g:nvim_tree_indent_markers = 1 "0 by default, this option shows indent markers when folders are open
let g:nvim_tree_hide_dotfiles = 1 "0 by default, this option hides files and folders starting with a dot `.`
let g:nvim_tree_git_hl = 0 "0 by default, will enable file highlight for git attributes (can be used without the icons).
let g:nvim_tree_highlight_opened_files = 1 "0 by default, will enable folder and file icon highlight for opened files/directories.
let g:nvim_tree_root_folder_modifier = ':~' "This is the default. See :help filename-modifiers for more options
let g:nvim_tree_tab_open = 1 "0 by default, will open the tree when entering a new tab and the tree was previously open
let g:nvim_tree_width_allow_resize  = 1 "0 by default, will not resize the tree when opening a file
let g:nvim_tree_disable_netrw = 0 "1 by default, disables netrw
let g:nvim_tree_hijack_netrw = 0 "1 by default, prevents netrw from automatically opening when opening directories (but lets you keep its other utilities)
let g:nvim_tree_add_trailing = 1 "0 by default, append a trailing slash to folder names
let g:nvim_tree_group_empty = 1 " 0 by default, compact folders that only contain a single folder into one node in the file tree
let g:nvim_tree_lsp_diagnostics = 1 "0 by default, will show lsp diagnostics in the signcolumn. See :help nvim_tree_lsp_diagnostics
let g:nvim_tree_disable_window_picker = 1 "0 by default, will disable the window picker.
let g:nvim_tree_special_files = [ 'README.md', 'Makefile', 'MAKEFILE' ] " List of filenames that gets highlighted with NvimTreeSpecialFile
let g:nvim_tree_show_icons = {
    \ 'git': 0,
    \ 'folders': 0,
    \ 'files': 0,
    \ }
"}}}

"{{{ === nvim-treesitter
lua <<EOF

require'nvim-treesitter.configs'.setup {
  highlight = {
    enable = true,
  },
  indent = {
    enable = true,
  }
}

local nvim_lsp = require('lspconfig')

local on_attach = function(client, bufnr)
  local function buf_set_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
  local function buf_set_option(...) vim.api.nvim_buf_set_option(bufnr, ...) end

  buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')

  local opts = { noremap=true, silent=true }

  buf_set_keymap('n', 'gD', '<cmd>lua vim.lsp.buf.declaration()<CR>', opts)
  buf_set_keymap('n', 'gd', '<cmd>lua vim.lsp.buf.definition()<CR>', opts)
  buf_set_keymap('n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>', opts)
  buf_set_keymap('n', 'K', '<cmd>lua vim.lsp.buf.hover()<CR>', opts)
  buf_set_keymap('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>', opts)
  buf_set_keymap('n', 'gy', '<cmd>lua vim.lsp.buf.type_definition()<CR>', opts)
  buf_set_keymap('n', '<space>en', '<cmd>lua vim.lsp.buf.rename()<CR>', opts)
  buf_set_keymap('n', '[d', '<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>', opts)
  buf_set_keymap('n', ']d', '<cmd>lua vim.lsp.diagnostic.goto_next()<CR>', opts)
  buf_set_keymap('n', 'gs','<cmd>lua vim.lsp.buf.signature_help()<CR>', opts)

end

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.completion.completionItem.snippetSupport = true

nvim_lsp.gopls.setup { 
  on_attach = on_attach;
  capabilities = capabilities;
  init_options = {
    usePlaceholders = true;
    linksInHover = false;
    allowModfileModifications = true;
  };
}

nvim_lsp.tsserver.setup {
  root_dir = nvim_lsp.util.root_pattern("tsconfig.json", "jsconfig.json", ".git");
  on_attach = on_attach;
  capabilities = capabilities;
}

vim.o.completeopt = "menuone,noselect"
require'compe'.setup {
  enabled = true;
  autocomplete = true;
  debug = false;
  min_length = 1;
  preselect = 'enable';
  throttle_time = 80;
  source_timeout = 200;
  incomplete_delay = 400;
  max_abbr_width = 100;
  max_kind_width = 100;
  max_menu_width = 100;
  documentation = true;

  source = {
    path = true;
    buffer = true;
    calc = true;
    nvim_lsp = true;
    nvim_lua = true;
    vsnip = true;
    ultisnips = true;
    spell = true;
  };
}

vim.api.nvim_set_keymap("i", "<C-Space> ", "compe#complete()", {noremap = true, silent = true, expr = true})
vim.api.nvim_set_keymap("i", "<CR>", "compe#confirm('<CR>')", {noremap = true, silent = true, expr = true})

EOF
"}}}

"{{{ === Git-messenger
let g:git_messenger_no_default_mappings=v:true
nmap M <Plug>(git-messenger)
"}}}

"{{{ === VimWiki
let g:vimwiki_list = [{'path': '~/vimwiki/',
                      \ 'syntax': 'markdown', 'ext': '.md'}]
" let g:vimwiki_folding = 'list:quick'
"}}}

" {{{ === NERDCommenter
let g:NERDCreateDefaultMappings = 0
let g:NERDSpaceDelims = 1
let g:NERDDefaultAlign = 'left'
" }}}

" " {{{ === Gitgutter
let g:gitgutter_map_keys = 0
let g:gitgutter_preview_win_floating = 0

let g:gitgutter_sign_added = '▌'
let g:gitgutter_sign_modified = '▌'
let g:gitgutter_sign_removed = '▁'
let g:gitgutter_sign_removed_first_line = '▌'
let g:gitgutter_sign_modified_removed = '▌'
let g:gitgutter_realtime = 1
highlight GitGutterDelete guifg=#F97CA9
highlight GitGutterAdd    guifg=#BEE275
highlight GitGutterChange guifg=#96E1EF
" }}}

" {{{ === Vim-go
let g:go_gopls_enabled = 0 " Disable vim-go gopls since we use coc-go gopls instead
let g:go_doc_keywordprg_enabled = 0
let g:go_def_mapping_enabled = 0
let g:go_code_completion_enabled = 0
let g:go_doc_keywordprg_enabled = 0


" let g:go_textobj_enabled= 0
let g:go_fmt_command = "goimports" " Refactor code when save
let g:go_doc_popup_window = 1 " Use popup windows of neovim
let g:go_fold_enable = ['block', 'import', 'varconst'] " fold settings

" Highlight settings
" let g:go_highlight_array_whitespace_error = 0
" let g:go_highlight_build_constraints      = 0
" let g:go_highlight_chan_whitespace_error  = 0
" let g:go_highlight_extra_types            = 0 " io.Reader
" let g:go_highlight_fields                 = 1
" let g:go_highlight_format_strings         = 1
" let g:go_highlight_function_calls         = 1
" let g:go_highlight_functions              = 1
" let g:go_highlight_function_parameters    = 0
" let g:go_highlight_generate_tags          = 0
" let g:go_highlight_operators              = 0
" let g:go_highlight_space_tab_error        = 0
" let g:go_highlight_string_spellcheck      = 0
" let g:go_highlight_types                  = 0 " struct and interfaces names
" let g:go_highlight_variable_assignments   = 0
" let g:go_highlight_variable_declarations  = 0
" }}}

" === Winresizer === {{{
let g:winresizer_start_key = '<C-T>'
" }}}

" === Markdown === {{{
let g:mkdp_auto_start = 0
let g:mkdp_echo_preview_url = 1
" }}}

"{{{ === FZF windows ===
" functions
function! Float()
    let width = float2nr(&columns * 0.8)
    let height = float2nr(&lines * 0.6)
    let opts = {
                \ 'relative': 'editor',
                \ 'row': (&lines - height) / 2,
                \ 'col': (&columns - width) / 2,
                \ 'width': width,
                \ 'height': height,
                \ }

    call nvim_open_win(nvim_create_buf(v:false, v:true), v:true, opts)
endfunction

" options
let g:fzf_layout = { 'window': 'call Float()' }
"}}}
