" .vimrc / init.vim
" The following vim/neovim configuration works for both Vim and NeoVim

" ensure vim-plug is installed and then load it
call functions#PlugLoad()
call plug#begin('~/.config/nvim/plugged')

" General {{{
	" Abbreviations
	abbr funciton function
	abbr teh the
	abbr tempalte template
	abbr fitler filter
	abbr cosnt const
	abbr attribtue attribute
	abbr attribuet attribute

	set autoread " detect when a file is changed

	set history=1000 " change history to 1000
	set textwidth=120

	set backupdir=~/.vim-tmp,~/.tmp,~/tmp,/var/tmp,/tmp
	set directory=~/.vim-tmp,~/.tmp,~/tmp,/var/tmp,/tmp

	if (has('nvim'))
		let g:python_host_prog = '/usr/local/bin/python2'
		let g:python3_host_prog = '/usr/local/bin/python3'
		" show results of substition as they're happening
		" but don't open a split
		set inccommand=nosplit
	endif

	set backspace=indent,eol,start " make backspace behave in a sane manner
	set clipboard=unnamed

	if has('mouse')
		set mouse=a
	endif

	" Searching
	set ignorecase " case insensitive searching
	set smartcase " case-sensitive if expresson contains a capital letter
	set hlsearch " highlight search results
	set incsearch " set incremental search, like modern browsers
	set nolazyredraw " don't redraw while executing macros

	set magic " Set magic on, for regex

	" error bells
	set noerrorbells
	set visualbell
	set t_vb=
	set tm=500
" }}}

" Appearance {{{
	set number " show line numbers
	set wrap " turn on line wrapping
	set wrapmargin=8 " wrap lines when coming within n characters from side
	set linebreak " set soft wrapping
	set showbreak=… " show ellipsis at breaking
	set autoindent " automatically set indent of new line
	set ttyfast " faster redrawing
	set diffopt+=vertical
	set laststatus=2 " show the satus line all the time
	set so=7 " set 7 lines to the cursors - when moving vertical
	set wildmenu " enhanced command line completion
	set hidden " current buffer can be put into background
	set showcmd " show incomplete commands
	set noshowmode " don't show which mode disabled for PowerLine
	set wildmode=list:longest " complete files like a shell
	set scrolloff=3 " lines of text around cursor
	set shell=$SHELL
	set cmdheight=1 " command bar height
	set title " set terminal title
	set showmatch " show matching braces
	set mat=2 " how many tenths of a second to blink

	" Tab control
	set noexpandtab " insert tabs rather than spaces for <Tab>
	set smarttab " tab respects 'tabstop', 'shiftwidth', and 'softtabstop'
	set tabstop=4 " the visible width of tabs
	set softtabstop=4 " edit as if the tabs are 4 characters wide
	set shiftwidth=4 " number of spaces to use for indent and unindent
	set shiftround " round indent to a multiple of 'shiftwidth'

	" code folding settings
	set foldmethod=syntax " fold based on indent
	set foldlevelstart=99
	set foldnestmax=10 " deepest fold is 10 levels
	set nofoldenable " don't fold by default
	set foldlevel=1

	" toggle invisible characters
	set list
	set listchars=tab:→\ ,eol:¬,trail:⋅,extends:❯,precedes:❮
	set showbreak=↪

	set t_Co=256 " Explicitly tell vim that the terminal supports 256 colors
	" switch cursor to line when in insert mode, and block when not
	set guicursor=n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50
	\,a:blinkwait700-blinkoff400-blinkon250-Cursor/lCursor
	\,sm:block-blinkwait175-blinkoff150-blinkon175

	if &term =~ '256color'
		" disable background color erase
		set t_ut=
	endif

	" enable 24 bit color support if supported
	if (has('mac') && empty($TMUX) && has("termguicolors"))
		set termguicolors
	endif

	" highlight conflicts
	match ErrorMsg '^\(<\|=\|>\)\{7\}\([^=].\+\)\?$'

	" Load colorschemes
	Plug 'chriskempson/base16-vim'
	Plug 'joshdick/onedark.vim'

	" Airline {{{
		Plug 'vim-airline/vim-airline'
		Plug 'vim-airline/vim-airline-themes'
		let g:airline_powerline_fonts=1
		let g:airline_left_sep=''
		let g:airline_right_sep=''
		let g:airline_theme='base16'
		let g:airline#extensions#tabline#show_splits = 0
		let g:airline#extensions#whitespace#enabled = 0
		" enable airline tabline
		let g:airline#extensions#tabline#enabled = 1
		" only show tabline if tabs are being used (more than 1 tab open)
		let g:airline#extensions#tabline#tab_min_count = 2
		" do not show open buffers in tabline
		let g:airline#extensions#tabline#show_buffers = 0
		" Show errors in airline from ALE
		let g:airline#extensions#ale#enabled = 1
	" }}}
" }}}

" General Mappings {{{
	" set a map leader for more key combos
	let mapleader = ','

	" remap esc
	inoremap jk <esc>

	" shortcut to save
	nmap <leader>, :w<cr>

	" set paste toggle
	set pastetoggle=<leader>v

	" edit ~/.config/nvim/init.vim
	map <leader>ev :e! ~/.config/nvim/init.vim<cr>
	" edit gitconfig
	map <leader>eg :e! ~/.gitconfig<cr>

	" clear highlighted search
	noremap <space> :set hlsearch! hlsearch?<cr>

	" activate spell-checking alternatives
	nmap ;s :set invspell spelllang=en<cr>

	" markdown to html
	nmap <leader>md :%!markdown --html4tags <cr>

	" remove extra whitespace
	nmap <leader><space> :%s/\s\+$<cr>
	nmap <leader><space><space> :%s/\n\{2,}/\r\r/g<cr>

	inoremap <expr> <C-j> pumvisible() ? "\<C-N>" : "\<C-j>"
	inoremap <expr> <C-k> pumvisible() ? "\<C-P>" : "\<C-k>"

	nmap <leader>l :set list!<cr>

	" Textmate style indentation
	vmap <leader>[ <gv
	vmap <leader>] >gv
	nmap <leader>[ <<
	nmap <leader>] >>

	" switch between current and last buffer
	nmap <leader>. <c-^>

	" enable . command in visual mode
	vnoremap . :normal .<cr>

	map <silent> <C-h> :call functions#WinMove('h')<cr>
	map <silent> <C-j> :call functions#WinMove('j')<cr>
	map <silent> <C-k> :call functions#WinMove('k')<cr>
	map <silent> <C-l> :call functions#WinMove('l')<cr>

	map <leader>wc :wincmd q<cr>

	" move line mappings
	" ∆ is <A-j> on macOS
	" ˚ is <A-k> on macOS
	nnoremap ∆ :m .+1<cr>==
	nnoremap ˚ :m .-2<cr>==
	inoremap ∆ <Esc>:m .+1<cr>==gi
	inoremap ˚ <Esc>:m .-2<cr>==gi
	vnoremap ∆ :m '>+1<cr>gv=gv
	vnoremap ˚ :m '<-2<cr>gv=gv

	" toggle cursor line
	nnoremap <leader>i :set cursorline!<cr>

	" scroll the viewport faster
	nnoremap <C-e> 3<C-e>
	nnoremap <C-y> 3<C-y>

	" moving up and down work as you would expect
	nnoremap <silent> j gj
	nnoremap <silent> k gk
	nnoremap <silent> ^ g^
	nnoremap <silent> $ g$

	" inoremap <tab> <c-r>=Smart_TabComplete()<CR>

	map <leader>r :call RunCustomCommand()<cr>
	" map <leader>s :call SetCustomCommand()<cr>
	let g:silent_custom_command = 0

	" helpers for dealing with other people's code
	nmap \t :set ts=4 sts=4 sw=4 noet<cr>
	nmap \s :set ts=4 sts=4 sw=4 et<cr>

	nnoremap <silent> <leader>u :call functions#HtmlUnEscape()<cr>

	command! Rm call functions#Delete()
	command! RM call functions#Delete() <Bar> q!
" }}}

" AutoGroups {{{
	" file type specific settings
	augroup configgroup
		autocmd!

		" automatically resize panes on resize
		autocmd VimResized * exe 'normal! \<c-w>='
		autocmd BufWritePost .vimrc,.vimrc.local,init.vim source %
		autocmd BufWritePost .vimrc.local source %
		" save all files on focus lost, ignoring warnings about untitled buffers
		autocmd FocusLost * silent! wa

		" make quickfix windows take all the lower section of the screen
		" when there are multiple windows open
		autocmd FileType qf wincmd J
		autocmd FileType qf nmap <buffer> q :q<cr>
	augroup END
" }}}

" General Functionality {{{
	" substitute, search, and abbreviate multiple variants of a word
	Plug 'tpope/vim-abolish'

	" search inside files using ack. Same as command line ack utility, but use :Ack
	Plug 'mileszs/ack.vim'

	" insert or delete brackets, parens, quotes in pair
	Plug 'jiangmiao/auto-pairs'

	" easy commenting motions
	Plug 'tpope/vim-commentary'

	" mappings which are simply short normal mode aliases for commonly used ex commands
	Plug 'tpope/vim-unimpaired'

	" endings for html, xml, etc. - ehances surround
	Plug 'tpope/vim-ragtag'

	" mappings to easily delete, change and add such surroundings in pairs, such as quotes, parens, etc.
	Plug 'tpope/vim-surround'

	" tmux integration for vim
	Plug 'benmills/vimux'

	" enables repeating other supported plugins with the . command
	Plug 'tpope/vim-repeat'

	" .editorconfig support
	Plug 'editorconfig/editorconfig-vim'

	" asynchronous build and test dispatcher
	Plug 'tpope/vim-dispatch'

	" netrw helper
	Plug 'tpope/vim-vinegar'

	" single/multi line code handler: gS - split one line into multiple, gJ - combine multiple lines into one
	Plug 'AndrewRadev/splitjoin.vim'

	" extended % matching
	Plug 'vim-scripts/matchit.zip'

	" detect indent style (tabs vs. spaces)
	Plug 'tpope/vim-sleuth'

    " Close buffers but keep splits
    Plug 'moll/vim-bbye'
	nmap <leader>b :Bdelete<cr>

    " Writing in vim {{{{
		Plug 'junegunn/limelight.vim'
		Plug 'junegunn/goyo.vim'
		let g:limelight_conceal_ctermfg = 240
	" }}}

	" context-aware pasting
	Plug 'sickill/vim-pasta'

	" NERDTree {{{
		Plug 'scrooloose/nerdtree', { 'on': ['NERDTreeToggle', 'NERDTreeFind'] }
		Plug 'Xuyuanp/nerdtree-git-plugin'
		Plug 'ryanoasis/vim-devicons'

		" Toggle NERDTree
		function! ToggleNerdTree()
			if @% != "" && (!exists("g:NERDTree") || (g:NERDTree.ExistsForTab() && !g:NERDTree.IsOpen()))
				:NERDTreeFind
			else 
				:NERDTreeToggle
			endif
		endfunction
        " toggle nerd tree
		nmap <silent> <leader>k :call ToggleNerdTree()<cr>
        " find the current file in nerdtree without needing to reload the drawer
        nmap <silent> <leader>y :NERDTreeFind<cr>

		let NERDTreeShowHidden=1
		" let NERDTreeDirArrowExpandable = '▷'
		" let NERDTreeDirArrowCollapsible = '▼'
		let g:NERDTreeIndicatorMapCustom = {
		\ "Modified"  : "✹",
		\ "Staged"    : "✚",
		\ "Untracked" : "✭",
		\ "Renamed"   : "➜",
		\ "Unmerged"  : "═",
		\ "Deleted"   : "✖",
		\ "Dirty"     : "✗",
		\ "Clean"     : "✔︎",
		\ 'Ignored'   : '☒',
		\ "Unknown"   : "?"
		\ }
	" }}}

	" FZF {{{
		Plug '/usr/local/opt/fzf'
		Plug 'junegunn/fzf.vim'
		let g:fzf_layout = { 'down': '~25%' }

		if isdirectory(".git")
			" if in a git project, use :GFiles
			nmap <silent> <leader>t :GFiles --cached --others --exclude-standard<cr>
		else
			" otherwise, use :FZF
			nmap <silent> <leader>t :FZF<cr>
		endif

		nmap <silent> <leader>r :Buffers<cr>
		nmap <silent> <leader>e :FZF<cr>
		nmap <leader><tab> <plug>(fzf-maps-n)
		xmap <leader><tab> <plug>(fzf-maps-x)
		omap <leader><tab> <plug>(fzf-maps-o)

		" Insert mode completion
		imap <c-x><c-k> <plug>(fzf-complete-word)
		imap <c-x><c-f> <plug>(fzf-complete-path)
		imap <c-x><c-j> <plug>(fzf-complete-file-ag)
		imap <c-x><c-l> <plug>(fzf-complete-line)

		nnoremap <silent> <Leader>C :call fzf#run({
		\	'source':
		\	  map(split(globpath(&rtp, "colors/*.vim"), "\n"),
		\		  "substitute(fnamemodify(v:val, ':t'), '\\..\\{-}$', '', '')"),
		\	'sink':    'colo',
		\	'options': '+m',
		\	'left':    30
		\ })<CR>

		command! FZFMru call fzf#run({
		\  'source':  v:oldfiles,
		\  'sink':	  'e',
		\  'options': '-m -x +s',
		\  'down':	  '40%'})

		command! -bang -nargs=* Find call fzf#vim#grep(
			\ 'rg --column --line-number --no-heading --follow --color=always '.<q-args>, 1,
			\ <bang>0 ? fzf#vim#with_preview('up:60%') : fzf#vim#with_preview('right:50%:hidden', '?'), <bang>0)
		command! -bang -nargs=? -complete=dir Files
			\ call fzf#vim#files(<q-args>, fzf#vim#with_preview(), <bang>0)
		command! -bang -nargs=? -complete=dir GFiles
			\ call fzf#vim#gitfiles(<q-args>, fzf#vim#with_preview(), <bang>0)
	" }}}

	" signify {{{
	    " Plug 'airblade/vim-gitgutter'
	    Plug 'mhinz/vim-signify'
	    let g:signify_vcs_list = [ 'git' ]
	    let g:signify_sign_add               = '+'
	    let g:signify_sign_delete            = '_'
	    let g:signify_sign_delete_first_line = '‾'
	    let g:signify_sign_change = '!'
	" }}}

	" vim-fugitive {{{
		Plug 'tpope/vim-fugitive'
		Plug 'tpope/vim-rhubarb' " hub extension for fugitive
		nmap <silent> <leader>gs :Gstatus<cr>
		nmap <leader>ge :Gedit<cr>
		nmap <silent><leader>gr :Gread<cr>
		nmap <silent><leader>gb :Gblame<cr>
	" }}}

	" ALE {{{
		Plug 'w0rp/ale' " Asynchonous linting engine
		let g:ale_change_sign_column_color = 0
		let g:ale_sign_column_always = 1
		let g:ale_sign_error = '✖'
		let g:ale_sign_warning = '⚠'

		let g:ale_linters = {
		\	'javascript': ['eslint'],
		\	'typescript': ['tsserver', 'tslint'],
		\	'html': []
		\}
	" }}}

	" UltiSnips {{{
		Plug 'SirVer/ultisnips' " Snippets plugin
		let g:UltiSnipsExpandTrigger="<tab>"
	" }}}
" }}}

" Language-Specific Configuration {{{
	" html / templates {{{
		" emmet support for vim - easily create markdup wth CSS-like syntax
		Plug 'mattn/emmet-vim', { 'for': ['html', 'javascript.jsx', 'eruby' ]}
		let g:user_emmet_settings = {
		\  'javascript.jsx': {
		\	   'extends': 'jsx',
		\  },
		\}

		" match tags in html, similar to paren support
		Plug 'gregsexton/MatchTag', { 'for': 'html' }

		" html5 support
		Plug 'othree/html5.vim', { 'for': 'html' }

		" mustache support
		Plug 'mustache/vim-mustache-handlebars'

		" pug / jade support
		Plug 'digitaltoad/vim-pug', { 'for': ['jade', 'pug'] }

		" Ruby / Ruby on Rails
		Plug 'tpope/vim-rails', { 'for': 'ruby' }
	" }}}

	" JavaScript {{{
		Plug 'pangloss/vim-javascript', { 'for': ['javascript', 'javascript.jsx', 'html'] }
		Plug 'moll/vim-node', { 'for': 'javascript' }
		Plug 'mxw/vim-jsx', { 'for': ['javascript.jsx', 'javascript'] }
		Plug 'ternjs/tern_for_vim', { 'for': ['javascript', 'javascript.jsx'], 'do': 'npm install' }
	" }}}

	" TypeScript {{{
		Plug 'leafgarland/typescript-vim', { 'for': 'typescript' }
		Plug 'Shougo/vimproc.vim', { 'do': 'make' }
		Plug 'Quramy/tsuquyomi', { 'for': 'typescript', 'do': 'npm install' }

		" TypeScript Options
		let g:tsuquyomi_completion_detail = 1
		let g:tsuquyomi_disable_default_mappings = 1
		let g:tsuquyomi_completion_detail = 1
	" }}}


	" Styles {{{
		Plug 'wavded/vim-stylus', { 'for': ['stylus', 'markdown'] }
		Plug 'groenewege/vim-less', { 'for': 'less' }
		Plug 'hail2u/vim-css3-syntax', { 'for': 'css' }
		Plug 'cakebaker/scss-syntax.vim', { 'for': 'scss' }
		Plug 'gko/vim-coloresque'
		Plug 'stephenway/postcss.vim', { 'for': 'css' }
	" }}}

	" markdown {{{
		Plug 'tpope/vim-markdown', { 'for': 'markdown' }

		" Open markdown files in Marked.app - mapped to <leader>m
		Plug 'itspriddle/vim-marked', { 'for': 'markdown', 'on': 'MarkedOpen' }
		nmap <leader>m :MarkedOpen!<cr>
		nmap <leader>mq :MarkedQuit<cr>
		nmap <leader>* *<c-o>:%s///gn<cr>

		" a simple tool for presenting slides in vim based on text files
		Plug 'sotte/presenting.vim', { 'for': 'markdown' }
	" }}}

	" JSON {{{
		Plug 'elzr/vim-json', { 'for': 'json' }
		let g:vim_json_syntax_conceal = 0
	" }}}

	Plug 'fatih/vim-go', { 'for': 'go' }
	Plug 'timcharper/textile.vim', { 'for': 'textile' }
	Plug 'lambdatoast/elm.vim', { 'for': 'elm' }
	Plug 'tpope/vim-endwise', { 'for': [ 'ruby', 'bash', 'zsh', 'sh' ]}
	Plug 'kchmck/vim-coffee-script', { 'for': 'coffeescript' }
" }}}

call plug#end()

" Colorscheme and final setup {{{
	" This call must happen after the plug#end() call to ensure
	" that the colorschemes have been loaded
	if filereadable(expand("~/.vimrc_background"))
		let base16colorspace=256
		source ~/.vimrc_background
	else
		let g:onedark_termcolors=16
		let g:onedark_terminal_italics=1
		colorscheme onedark
	endif
	syntax on
	filetype plugin indent on
	" make the highlighting of tabs and other non-text less annoying
	highlight SpecialKey ctermfg=236
	highlight NonText ctermfg=236

	" make comments and HTML attributes italic
	highlight Comment cterm=italic
	highlight htmlArg cterm=italic
	highlight xmlAttrib cterm=italic
	highlight Type cterm=italic
	highlight Normal ctermbg=none

" }}}

" vim:set foldmethod=marker foldlevel=0
