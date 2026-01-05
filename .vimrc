" dein.vim settings {{{
let s:dein_dir = expand('~/.cache/dein')
let s:dein_repo_dir = s:dein_dir . '/repos/github.com/Shougo/dein.vim'

if &runtimepath !~# '/dein.vim'
  if !isdirectory(s:dein_repo_dir)
    execute '!git clone https://github.com/Shougo/dein.vim' s:dein_repo_dir
  endif
  execute 'set runtimepath^=' . fnamemodify(s:dein_repo_dir, ':p')
endif

if dein#load_state(s:dein_dir)
  call dein#begin(s:dein_dir)

  let g:rc_dir    = expand('~/.vim/rc')
  let s:toml      = g:rc_dir . '/dein.toml'
  let s:lazy_toml = g:rc_dir . '/dein_lazy.toml'

  call dein#load_toml(s:toml,      {'lazy': 0})
  call dein#load_toml(s:lazy_toml, {'lazy': 1})

  call dein#end()
  call dein#save_state()
endif

if dein#check_install()
  call dein#install()
endif

let s:removed_plugins = dein#check_clean()
if len(s:removed_plugins) > 0
  call map(s:removed_plugins, "delete(v:val, 'rf')")
  call dein#recache_runtimepath()
endif

filetype plugin indent on
syntax enable

" leader
let mapleader = ","

" encoding
set encoding=utf-8
scriptencoding utf-8
set fileencodings=utf-8,iso-2022-jp,cp932,sjis,euc-jp
set fileformats=unix,dos,mac

" cursor
set backspace=eol,indent,start
set wildmode=list:longest
set nrformats=""
noremap j gj
noremap k gk
noremap <down> gj
noremap <up> gk

" tab indent
set shiftwidth=4
set expandtab
set tabstop=4
set smarttab
set autoindent
set smartindent

" buffer
set nobackup
set noswapfile
set hidden
set splitbelow
set splitright

" color
set background=dark
colorscheme womprat

" information
set number

" special chars
set list
set listchars=tab:>\ ,trail:-,nbsp:%,extends:>,precedes:<
hi ZenkakuSpace cterm=underline ctermfg=lightblue guibg=#666666
au BufNewFile,BufRead * match ZenkakuSpace /　/
set ambiwidth=double
set showmatch

" spell
set nospell
let g:enable_spelunker_vim = 1
highlight SpelunkerSpellBad cterm=underline ctermfg=160 gui=underline guifg=#9e9e9e
highlight SpelunkerComplexOrCompoundWord cterm=underline ctermfg=NONE gui=underline guifg=NONE

" search
set ignorecase
set smartcase
set incsearch
set hlsearch
set nowrapscan
nmap * *N

" Command Map
" Buffre Close
nnoremap <Leader>d :bp<bar>sp<bar>bn<bar>bd<bar>bn<CR>
" Chrome Reload
nnoremap <Leader>cr :ChromeReload<CR><C-l>
" let g:user_emmet_leader_key='<c-t>'
nnoremap <Leader>sc :SyntasticCheck<CR>
" calc
nnoremap <LEADER>ca :call Calc()<CR>
" copilot chat
" nnoremap :cp :CopilotChat<CR>

" buffer
nnoremap <C-p> :bp<CR>
nnoremap <C-n> :bn<CR>

" no copy on delete
nnoremap x "_x
" nnoremap dd "_dd
nnoremap D "_D
nnoremap s "_s

" move lines
" nnoremap J :m .+1<CR>==
" nnoremap K :m .-2<CR>==
" inoremap J <Esc>:m .+1<CR>==gi
" inoremap K <Esc>:m .-2<CR>==gi
vnoremap J :m '>+1<CR>gv=gv
vnoremap K :m '<-2<CR>gv=gv

" vnoremap y :set clipboard+=unnamed<CR>y<CR>:set clipboard-=unnamed<CR>
":let @+=@0
vnoremap y "+y
" vim-airline
let g:airline#extensions#tabline#enabled = 1
let g:airline_theme='jellybeans'
let g:airline#extensions#default#layout = [
    \ [ 'c'],
    \ [ 'y', 'error', 'warning']
    \ ]

" syntax check
set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*

let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_open = 0
let g:syntastic_check_on_wq = 1
let g:syntastic_enable_signs=1

" tags
set tags=.tags;$HOME

function! s:execute_ctags() abort
  let tag_name = '.tags'
  let tags_path = findfile(tag_name, '.;')
  if tags_path ==# ''
    return
  endif

  let tags_dirpath = fnamemodify(tags_path, ':p:h')
  execute 'silent !cd' tags_dirpath '&& ctags -R --languages=php --php-kinds=cdfin -f' tag_name '2> /dev/null &'
endfunction

augroup ctags
  autocmd!
  autocmd BufWritePost * call s:execute_ctags()
augroup END

nmap <F8> :TagbarToggle<CR>
nnoremap <C-]> g<C-]>
inoremap <C-]> <ESC>g<C-]>

" xdebug
let g:vdebug_force_ascii = 1
let g:vdebug_options= {
\    "ide_key" : "PHP_IDE_DEBUG",
\    "server" : "127.0.0.1",
\    "port" : 9003,
\    "timeout" : 20,
\    "on_close" : 'detach',
\    "break_on_open" : 0,
\    "remote_path" : "",
\    "local_path" : "",
\    "debug_window_level" : 0,
\    "debug_file_level" : 2,
\    "debug_file" : "/tmp/xdebug.log",
\    "path_maps" : {
\       '/app' : '/Users/'.$USER.'/Projects/HotStartup/peraichi',
\    },
\    "window_arrangement" : ["DebuggerWatch", "DebuggerStack"]
\}

let g:vdebug_keymap = {
\    "run" : "<F5>",
\    "run_to_cursor" : "<F9>",
\    "step_over" : "<F2>",
\    "step_into" : "<F3>",
\    "step_out" : "<F4>",
\    "close" : "<F6>",
\    "detach" : "<F7>",
\    "set_breakpoint" : "<F10>",
\    "get_context" : "<F11>",
\    "eval_under_cursor" : "<F12>",
\    "eval_visual" : "<Leader>e"
\}

imap <M-DOWN> <Plug>(copilot-next)
imap <M-UP> <Plug>(copilot-previous)

:lua require('copilot_chat_config.init')

" Find files using Telescope command-line sugar.
nnoremap <Leader>ff <cmd>Telescope find_files<cr>
nnoremap <Leader>fg <cmd>Telescope live_grep<cr>
nnoremap <Leader>fb <cmd>Telescope buffers<cr>
nnoremap <Leader>fh <cmd>Telescope help_tags<cr>

" Terminal
tnoremap <Esc> <C-\><C-n>
