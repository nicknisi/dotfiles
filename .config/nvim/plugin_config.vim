
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Plugins Config:
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

"{{{ === nvim-treesitter
lua <<EOF
require'nvim-treesitter.configs'.setup {
  highlight = {
    enable = true,
  },
}
EOF
"}}}

"{{{ === Git-messenger
let g:git_messenger_no_default_mappings=v:true
nmap M <Plug>(git-messenger)
"}}}

"{{{ === VimWiki
let g:vimwiki_list = [{'path': '~/vimwiki/',
                      \ 'syntax': 'markdown', 'ext': '.md'}]
let g:vimwiki_folding = 'list:quick'
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
let g:go_textobj_enabled= 0
let g:go_fmt_command = "goimports" " Refactor code when save
let g:go_doc_popup_window = 1 " Use popup windows of neovim
let g:go_fold_enable = ['block', 'import', 'varconst'] " fold settings

" Highlight settings
let g:go_highlight_array_whitespace_error = 0
let g:go_highlight_build_constraints      = 0
let g:go_highlight_chan_whitespace_error  = 0
let g:go_highlight_extra_types            = 0 " io.Reader
let g:go_highlight_fields                 = 1
let g:go_highlight_format_strings         = 1
let g:go_highlight_function_calls         = 1
let g:go_highlight_functions              = 1
let g:go_highlight_function_parameters    = 0
let g:go_highlight_generate_tags          = 0
let g:go_highlight_operators              = 0
let g:go_highlight_space_tab_error        = 0
let g:go_highlight_string_spellcheck      = 0
let g:go_highlight_types                  = 0 " struct and interfaces names
let g:go_highlight_variable_assignments   = 0
let g:go_highlight_variable_declarations  = 0
" }}}

" === Latex_preview === {{{
let g:livepreview_previewer = 'open -a Preview'
"}}}

" === Coc-nvim === {{{
" Set default python path
let g:python_host_prog = '/usr/local/bin/python'
let g:python3_host_prog = '/usr/local/bin/python3'
" }}}

" === Winresizer === {{{
let g:winresizer_start_key = '<C-T>'
" }}}

" === Markdown === {{{
let g:mkdp_auto_start = 0
let g:mkdp_echo_preview_url = 1
" }}}

" === Nerdtree === {{{
" Show hidden files/directories
let g:NERDTreeShowHidden = 1

" Remove bookmarks and help text from NERDTree
let g:NERDTreeMinimalUI = 1

" Custom icons for expandable/expanded directories
let g:NERDTreeDirArrowExpandable = ''
let g:NERDTreeDirArrowCollapsible = ''
let g:NERDTreeAutoDeleteBuffer = 1
let loaded_netrwPlugin = 1

" Hide certain files and directories from NERDTree
let g:NERDTreeIgnore = [
      \'^\.DS_Store$', 
      \'^tags$', 
      \'\.git$[[dir]]',
      \'\.idea$[[dir]]',
      \'\.sass-cache$',
      \'etcd*[[file]]',
      \'\.etcd*[[file]]'
      \]

" Disable highlight of file extension
let g:NERDTreeDisableFileExtensionHighlight = 1
highlight! link NERDTreeFlags NERDTreeDir
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
