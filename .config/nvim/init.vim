  " Set Runtime for config to work in Widows and Unix
set termguicolors

" ------------------------------------------------------
" Plug Specific
" ------------------------------------------------------
if isdirectory("/usr/share/nvim/plugged")
  let g:plug_dir="/usr/share/nvim/plugged"
else
  let g:plug_dir="~/.config/nvim/plugged"
endif

if has("win32")
  let g:python3_host_prog='C:\Python310\python.exe'
  let g:plug_dir="~/AppData/Local/nvim-plugged"

  let g:clipboard = {
    \   'name': 'WslClipboard',
    \   'copy': {
    \      '+': 'clip.exe',
    \      '*': 'clip.exe',
    \    },
    \   'paste': {
    \      '+': 'powershell.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
    \      '*': 'powershell.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
    \   },
    \   'cache_enabled': 0,
    \ }
endif


call plug#begin(g:plug_dir)
Plug 'jwalton512/vim-blade'           " Blade Syntax Support
Plug 'posva/vim-vue'                  " Vue Syntax Support
Plug 'othree/html5.vim'               " Html5 Syntax Support
Plug 'lilydjwg/colorizer'             " Html5 Syntax Support
Plug 'DougBeney/pickachu'             " File and Color Picker
Plug 'airblade/vim-rooter'            " Project Root

" PHP Plugins
Plug 'StanAngeloff/php.vim'           " Syntax Support
Plug 'tobyS/pdv'                      " Documentor for VIM
Plug 'tobyS/vmustache'                " Documentor Dependency
Plug 'joonty/vim-phpqa'               " Lint
Plug 'arnaud-lb/vim-php-namespace'    " Import Export
"Plug 'junegunn/fzf', { 'do': { -> fzf#install()  }  } " Fuzzy Finder Install
Plug 'junegunn/fzf.vim'               " Fuzzy Finder
Plug 'tpope/vim-vinegar'              " Native file browser with -
Plug 'scrooloose/nerdtree'            " File browser
Plug 'rking/ag.vim'                   " Search and replace plaguin
Plug 'skwp/greplace.vim'              " Search and replace across many files
Plug 'PotatoesMaster/i3-vim-syntax'
Plug 'tomtom/tlib_vim'                " Helpers
Plug 'tomtom/tcomment_vim'            " Commenting Plugin
Plug 'tpope/vim-commentary'           " Comment Plugin
Plug 'tpope/vim-surround'             " Souround with various tags
Plug 'stephpy/vim-php-cs-fixer'       " File Formatter
Plug 'SirVer/ultisnips'               " Snippets Engine
"Plug 'jiangmiao/auto-pairs'           " Doubles Quotes, Parenthesis etc.
Plug 'vim-airline/vim-airline'        " Vim status bar
Plug 'jeetsukumaran/vim-buffergator'  " Vim buffer management
"Plug 'craigemery/vim-autotag'        " Update Ctags automatically
Plug 'MarcWeber/vim-addon-mw-utils'   " Helpers
Plug 'lambdalisue/suda.vim'           " SudaWrite/SudaRead


call plug#end()                       " *required


" " Temporary workaround for: https://github.com/neovim/neovim/issues/1716
" if has("nvim")
"   command! W w !sudo -n tee % > /dev/null || echo "Press <leader>w to authenticate and try again"
"   map <leader>w :new<cr>:term sudo true<cr>
" else
"   command! W w !sudo tee % > /dev/null
" end

" ------------------------------------------------------
" General
" ------------------------------------------------------
filetype off                                      " Required for Vundle
filetype plugin indent on                         " Enable Indenting
syntax on                                         " Enable Syntax Highlighting
let mapleader = ","                               " Chane <leader> from '\'  to ',
let s:fontsize = 12
set hidden                                        " Hides Buffers instead of closing
set fileformat=unix                               " File Endings in unix format,
set backspace=indent,eol,start whichwrap+=<,>,[,]
set noerrorbells novisualbell t_vb=               " No Error Bells
set autowriteall                                  " Automatically Write the file
set complete=.,u,w,b                              " Set Autocompletion variable
set hlsearch                                      " Highlighting search matches
set incsearch                                     " Enable incremental search
set tabstop=2 shiftwidth=2 expandtab              " 2 spaces on tab
set nowrap                                        " don't wrap lines
set showmatch                                     " set show matching parenthesis
set copyindent                                    " copy the previous indentation on autoindenting
set ignorecase                                    " ignore case when searching
set smartcase                                     " ignore case if search pattern is all lowercase,
set smarttab                                      " insert tabs on the start of a line according to
set history=1000                                  " remember more commands and search history
set undolevels=1000                               " use many muchos levels of undo
set wildignore=*.swp,*.bak,*.pyc,*.class
set autoread                                      " Automatically reload file when changed outside of buffer
set encoding=utf-8
set clipboard^=unnamed,unnamedplus
set formatoptions-=cro
set listchars=eol:$,tab:→\ ,trail:~,extends:>,precedes:<,extends:#,nbsp:.,space:.
set shell=fish\ -i
set directory^=$HOME/.vim/tmp//

" Visuals
" ------------------------------------------------------
colorscheme legacy                  "Default Colour scheme
set number                          "Enable Line Numbers
set rnu                             "Relative line numbers
set mouse=a

" Line number Color Settings
hi CursorLineNR cterm=bold guibg=#135C96
hi LineNr guifg=#325176 ctermfg=255 guibg=bg gui=NONE


" Mappings
" ------------------------------------------------------
nnoremap <F7> mzgg=G`z
" Shift + Insert to paste from clipboard
cmap <S-Insert> <C-R>+
" Allow saving of files as sudo when I forgot to start vim using sudo.
cmap w!! SudaWrite
" show hidden characters
noremap <F5> :set list!<cr>
inoremap <F5> <c-o>:set list!<cr>
cnoremap <F5> <c-c>:sat list!<cr>

" indent
xnoremap < <gv
xnoremap > >gv
noremap <m-j> <<
noremap <m-k> >>
imap <m-j> <c-D>
imap <m-k> <c-T>


imap jk <Esc>;
nmap <silent><leader>et :e ~/.config/alacritty/alacritty.yml<cr>
nmap <silent><leader>ev :e $MYVIMRC<cr>
nmap <silent><leader>er :e ~/Readme.md<cr>
nmap <silent><leader>eh :e /etc/hosts<cr>

if has("win32")
  nmap <silent><leader>eh :e C:\Windows\System32\drivers\etc\hosts<cr>
  nmap <silent><leader>ea :e $HOME\winconf\powershell\modules\aliases\aliases.psm1<cr>
  nmap <silent><leader>ep :e $HOME\winconf\powershell\Microsoft.PowerShell_profile.ps1<cr>
else
  nmap <silent><leader>eh :e /etc/hosts<cr>
  nmap <silent><leader>ea :e ~/dotfiles/.config/.aliasrc<cr>
  nmap <silent><leader>ep :e ~/.profile<cr>
endif

nmap <silent><leader>ex :e ~/dotfiles/.config/xmonad/xmonad.hs<cr>
nmap <silent><leader>eb :e ~/dotfiles/.config/polybar/config<cr>
nmap <silent><leader>ef :e ~/dotfiles/.config/fish/config.fish<cr>
nmap <silent><leader>sv :so $MYVIMRC<cr>

" Improved Navigation
noremap j gj
noremap k gk

" Pick color
nmap <leader>p :Pick<cr>

" Remove search highlighting
nmap <leader><space> :nohlsearch<cr>

" Delete all buffers
nmap <leader>bda :bufdo bd!<cr>
nmap <leader>bd :bd<cr>

" Tabulator
nnoremap <silent><leader>to :tabonly<cr>
nnoremap <silent><leader>tw :tabclose<cr>
nnoremap <silent><leader>tn :tabnew<cr>
nnoremap <F2> :tabprevious<cr>
nnoremap <F3> :tabnext<cr>

"To open a new empty buffev
nmap <leader>T :enew<cr>

" Move to the next buffer
nmap <leader>l :bnext<cr>
nmap <leader>h :bprevious<cr>

" Close the current buffer and move to the previous one
" This replicates the idea of closing a tab
nmap <leader>bq :bp <BAR> bd #<cr>

" CTags
nnoremap <silent><leader>rel :!ctagsx<cr>
nnoremap <silent><leader>f :tag<space>

" Quickfix Toggle
nnoremap <leader>q :call QuickfixToggle()<cr>
let g:quickfix_is_open = 0
function! QuickfixToggle()
  if g:quickfix_is_open
    cclose
    let g:quickfix_is_open = 0
    execute g:quickfix_return_to_window . "wincmd w"
  else
    let g:quickfix_return_to_window = winnr()
    copen
    let g:quickfix_is_open = 1
  endif
endfunction

" Splits Management
set splitbelow
set splitright
nmap <c-h> <c-w><c-h>
nmap <c-j> <c-w><c-j>

nmap <c-k> <c-w><c-k>
nmap <c-l> <c-w><c-l>
nmap <silent><leader>g :split<cr>
nmap <silent><leader>v :vsplit<cr>

" resize horzontal split window
nmap <c-up>     <c-w>-<c-w>-
nmap <c-down>   <c-w>+<c-w>+
" resize vertical split window
nmap <c-left>   <c-w>><c-w>>
nmap <c-right>  <c-w><<c-w><

"------------------------------------------------------
" NERDTree Specific
"------------------------------------------------------
" General Settings
let NERDTreeChDirMode=2
let NERDTreeHijackNetrw=0
let NERDTreeShowHidden=1
let g:nerdtree_tabs_open_on_console_startup=1
let g:NERDTreeDirArrows=0
" NERDtree Toogle ALT + O
nnoremap <silent><m-`> :NERDTreeToggle<cr>

"------------------------------------------------------
" Ctrl P FfF
"------------------------------------------------------
" [Buffers] Jump to the existing window if possible
let g:fzf_buffers_jump = 1
" [[B]Commits] Customize the options used by 'git log':
let g:fzf_commits_log_options = '--graph --color=always --format="%C(auto)%h%d %s %C(black)%C(bold)%cr"'
" [Tags] Command to generate tags file
let g:fzf_tags_command = 'ctags -R'

function! s:build_quickfix_list(lines)
  call setqflist(map(copy(a:lines), '{ "filename": v:val }'))
  copen
  cc
endfunction

let g:fzf_action = {
      \ 'ctrl-q': function('s:build_quickfix_list'),
      \ 'ctrl-t': 'tab split',
      \ 'ctrl-x': 'split',
      \ 'ctrl-v': 'vsplit' }

" Default fzf layout
" - down / up / left / right
let g:fzf_layout = { 'down': '~30%' }
let g:fzf_history_dir = '~/.local/share/fzf-history'

nnoremap <leader><leader> :Files<CR>
nnoremap <C-P>            :Files<CR>
nnoremap <leader>C        :Colors<CR>
nnoremap <leader><CR>     :Buffers<CR>
nnoremap <leader>fl       :Lines<CR>
nnoremap <leader>ag       :Ag! <C-R><C-W><CR>
nnoremap <leader>m        :History<CR>

"------------------------------------------------------
" airblade / vim-rooter
"------------------------------------------------------
let g:rooter_change_directory_for_non_project_files = 'current'
" directories and yaml files
let g:rooter_patterns = ['.git/']

"------------------------------------------------------
" Greplace Specific
"------------------------------------------------------
set grepprg=ag
let g:grep_cmd_opts = '--line-numbers --noheading'

" ------------------------------------------------------
" UltiSnips Specific
" ------------------------------------------------------
" Trigger configuration. Do not use <tab> if you use YouCompleteMe.
let g:UltiSnipsExpandTrigger="<tab>"
let g:UltiSnipsJumpForwardTrigger="<tab>"
let g:UltiSnipsJumpBackwardTrigger="<s-tab>"

" ------------------------------------------------------
" PhpQA Specific
" ------------------------------------------------------
" Don't run messdetector on save (default = 1)
let g:phpqa_messdetector_autorun = 0
" Don't run codesniffer on save (default = 1)
let g:phpqa_codesniffer_autorun = 0
" Show code coverage on load (default = 0)
let g:phpqa_codecoverage_autorun = 1

" ------------------------------------------------------
" Buffergator
" ------------------------------------------------------
" Use the right side of the screen
let g:buffergator_viewport_split_policy = 'R'
" I want my own keymappings...
let g:buffergator_suppress_keymaps = 1
" Looper buffers
let g:UltiSnipsJumpBackwardTrigger="<s-tab>"

" ------------------------------------------------------
" PhpQA Specific
" ------------------------------------------------------
" Don't run messdetector on save (default = 1)
let g:phpqa_messdetector_autorun = 0
" Don't run codesniffer on save (default = 1)
let g:phpqa_codesniffer_autorun = 0
" Show code coverage on load (default = 0)
let g:phpqa_codecoverage_autorun = 1

" ------------------------------------------------------
" Buffergator
" ------------------------------------------------------
" Use the right side of the screen
let g:buffergator_viewport_split_policy = 'R'
" I want my own keymappings...
let g:buffergator_suppress_keymaps = 1
" Looper buffers
" let g:buffergator_mru_cycle_loop = 1
" Go to the previous buffer open
nmap <leader>jj :BuffergatorMruCyclePrev<cr>
" Go to the next buffer open
" View the entire list of buffers open
nmap <leader>bl :BuffergatorToggle<cr>
" Shared bindings from Solution #1 from earlier
nmap <leader>T :enew<cr>
nmap <leader>bq :bp <BAR> bd #<cr>

" ------------------------------------------------------
" Remove Trailing Space
" ------------------------------------------------------
fun! <SID>StripTrailingWhitespaces()
  let l = line(".")
  let c = col(".")
  %s/\s\+$//e
  call cursor(l, c)
  retab
endfun

" ------------------------------------------------------
" Auto Commands
" ------------------------------------------------------
" Source configs
augroup autosourcing
  autocmd!
  autocmd FileType java,php,ruby,python,javascript,ini,conf,vim autocmd BufWritePre <buffer> :call <SID>StripTrailingWhitespaces()
  autocmd BufWritePost $MYVIMRC source $MYVIMRC
  autocmd BufWritePost ~/dotfiles/scripts/x11-synaptics.sh silent! !sudo -A ~/dotfiles/scripts/x11-synaptics.sh
  autocmd BufWritePost ~/.config/dunst/dunstrc silent! !killall dunst & dunst &
  "Run xrdb whenever Xdefaults or Xresources are updated.
  autocmd BufWritePost *Xresources,*Xdefaults silent! !xrdb %
augroup END

" ------------------------------------------------------
" Enable Mouse SupporEnable Mouse Support
" ------------------------------------------------------
fun! s:ToggleMouse()
  if !exists("s:old_mouse")
    let s:old_mouse = "a"
  endif

  if &mouse == ""
    let &mouse = s:old_mouse
    echo "Mouse is for Vim (" . &mouse . ")"
  else
    let s:old_mouse = &mouse
    let &mouse=""
    echo "Mouse is for terminal"
  endif
endfunction
