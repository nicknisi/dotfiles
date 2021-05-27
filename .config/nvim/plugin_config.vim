
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Plugins Config:
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

"{{{ === nvim-treesitter
lua <<EOF

require('formatter').setup({
  logging = false,
  filetype = {
    javascript = {
        -- prettier
       function()
          return {
            exe = "prettier",
            args = {"--stdin-filepath", vim.api.nvim_buf_get_name(0), '--single-quote'},
            stdin = true
          }
        end
    }
  }
})


require'nvim-treesitter.configs'.setup {
  highlight = {
    enable = true,
  },
  indent = {
    enable = true,
  }
}

local nvim_lsp = require('lspconfig')

nvim_lsp.diagnosticls.setup {
  on_attach = on_attach_vim,
  filetypes = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
    "typescript.tsx",
    "css",
    "scss",
  },
  init_options = {
    linters = {
      eslint = {
        command = "eslint",
        rootPatterns = {".git", ".eslintrc.cjs", ".eslintrc", ".eslintrc.json", ".eslintrc.js"},
        debounce = 100,
        args = {"--stdin", "--stdin-filename", "%filepath", "--format", "json"},
        sourceName = "eslint",
        parseJson = {
          errorsRoot = "[0].messages",
          line = "line",
          column = "column",
          endLine = "endLine",
          endColumn = "endColumn",
          message = "[eslint] ${message} [${ruleId}]",
          security = "severity",
        },
        securities = {[2] = "error", [1] = "warning"},
      },
    },
    filetypes = {
      javascript = "eslint",
      javascriptreact = "eslint",
      typescript = "eslint",
      typescriptreact = "eslint",
      ["typescript.tsx"] = "eslint",
    },
    formatters = {},
    formatFiletypes = {},
  },
}

-- Use an on_attach function to only map the following keys 
-- after the language server attaches to the current buffer
local on_attach = function(client, bufnr)
  local function buf_set_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
  local function buf_set_option(...) vim.api.nvim_buf_set_option(bufnr, ...) end

  --Enable completion triggered by <c-x><c-o>
  buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')

  -- Mappings.
  local opts = { noremap=true, silent=true }

  -- See `:help vim.lsp.*` for documentation on any of the below functions
  buf_set_keymap('n', 'gD', '<Cmd>lua vim.lsp.buf.declaration()<CR>', opts)
  buf_set_keymap('n', 'gd', '<Cmd>lua vim.lsp.buf.definition()<CR>', opts)
  buf_set_keymap('n', 'K', '<Cmd>lua vim.lsp.buf.hover()<CR>', opts)
  buf_set_keymap('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>', opts)
  buf_set_keymap('n', '<C-k>', '<cmd>lua vim.lsp.buf.signature_help()<CR>', opts)
  buf_set_keymap('n', '<space>wa', '<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>', opts)
  buf_set_keymap('n', '<space>wr', '<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>', opts)
  buf_set_keymap('n', '<space>wl', '<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>', opts)
  buf_set_keymap('n', '<space>D', '<cmd>lua vim.lsp.buf.type_definition()<CR>', opts)
  buf_set_keymap('n', '<space>rn', '<cmd>lua vim.lsp.buf.rename()<CR>', opts)
  buf_set_keymap('n', '<space>ca', '<cmd>lua vim.lsp.buf.code_action()<CR>', opts)
  buf_set_keymap('n', 'gR', '<cmd>lua vim.lsp.buf.references()<CR>', opts)
  buf_set_keymap('n', '<space>e', '<cmd>lua vim.lsp.diagnostic.show_line_diagnostics()<CR>', opts)
  buf_set_keymap('n', '[d', '<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>', opts)
  buf_set_keymap('n', ']d', '<cmd>lua vim.lsp.diagnostic.goto_next()<CR>', opts)
  buf_set_keymap('n', '<space>q', '<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>', opts)
  buf_set_keymap("n", "<space>f", "<cmd>lua vim.lsp.buf.formatting()<CR>", opts)

end

-- Use a loop to conveniently call 'setup' on multiple servers and
-- map buffer local keybindings when the language server attaches
local servers = { "gopls", "tsserver" }
for _, lsp in ipairs(servers) do
  nvim_lsp[lsp].setup { on_attach = on_attach }
end

vim.o.completeopt = "menu,menuone,noselect"
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

-- settings without a patched font or icons
require("trouble").setup {
    position = "bottom", -- position of the list can be: bottom, top, left, right
    height = 10, -- height of the trouble list when position is top or bottom
    width = 50, -- width of the list when position is left or right
    icons = true, -- use devicons for filenames
    mode = "lsp_workspace_diagnostics", -- "lsp_workspace_diagnostics", "lsp_document_diagnostics", "quickfix", "lsp_references", "loclist"
    fold_open = "", -- icon used for open folds
    fold_closed = "", -- icon used for closed folds
    action_keys = { -- key mappings for actions in the trouble list
        close          = "<esc>", -- close the list
        cancel         = "q", -- cancel the preview and get back to your last window / buffer / cursor
        refresh        = "r", -- manually refresh
        jump           = { "<cr>" }, -- jump to the diagnostic or open / close folds
        open_split     = { "<c-x>" }, -- open buffer in new split
        open_vsplit    = { "<c-v>" }, -- open buffer in new vsplit
        open_tab       = { "<c-t>" }, -- open buffer in new tab
        jump_close     = {"o"}, -- jump to the diagnostic and close the list
        toggle_mode    = "m", -- toggle between "workspace" and "document" diagnostics mode
        toggle_preview = "P", -- toggle auto_preview
        hover          = "K", -- opens a small poup with the full multiline message
        preview        = "p", -- preview the diagnostic location
        close_folds    = {"zM", "zm"}, -- close all folds
        open_folds     = {"zR", "zr"}, -- open all folds
        toggle_fold    = {"zA", "za"}, -- toggle fold of current file
        previous       = "k", -- preview item
        next           = "j" -- next item
    },
    indent_lines = true, -- add an indent guide below the fold icons
    auto_open = false, -- automatically open the list when you have diagnostics
    auto_close = false, -- automatically close the list when you have no diagnostics
    auto_preview = true, -- automatyically preview the location of the diagnostic. <esc> to close preview and go back to last window
    auto_fold = false, -- automatically fold a file trouble list at creation
    signs = {
        -- icons / text used for a diagnostic
        error = "",
        warning = "",
        hint = "",
        information = "",
        other = "﫠"
    },
    use_lsp_diagnostic_signs = false -- enabling this will use the signs defined in your lsp client
}

vim.api.nvim_set_keymap("n", "gr", "<cmd>Trouble lsp_references<cr>", {silent = true, noremap = true})

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

" === Coc-nvim === {{{
" Set default python path
let g:python_host_prog = '/usr/local/bin/python'
let g:python3_host_prog = '/usr/local/bin/python3'
let g:coc_global_extensions = [
      \ 'coc-marketplace',
      \ 'coc-explorer',
      \ 'coc-json',
      \ 'coc-go',
      \ 'coc-rust-analyzer',
      \ 'coc-pyright',
      \ 'coc-eslint',
      \ 'coc-prettier',
      \ 'coc-snippets',
      \]

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
