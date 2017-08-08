" user selected options
set background=dark
set incsearch
set cindent
set wildmenu
set wildmode=list:longest,full
set number
set mouse=a
set pastetoggle=<F3>

if v:lang =~ "utf8$" || v:lang =~ "UTF-8$"
   set fileencodings=utf-8,latin1
endif

set nocompatible	" Use Vim defaults (much better!)
set bs=2		" allow backspacing over everything in insert mode
"set ai			" always set autoindenting on
"set backup		" keep a backup file
set viminfo='20,\"50	" read/write a .viminfo file, don't store more
			" than 50 lines of registers
set history=50		" keep 50 lines of command line history
set ruler		" show the cursor position all the time

" Only do this part when compiled with support for autocommands
if has("autocmd")
  " In text files, always limit the width of text to 78 characters
  autocmd BufRead *.txt set tw=78
  " When editing a file, always jump to the last cursor position
  autocmd BufReadPost *
  \ if line("'\"") > 0 && line ("'\"") <= line("$") |
  \   exe "normal g'\"" |
  \ endif
endif

if has("cscope")
   set csprg=/usr/bin/cscope
   set csto=0
   set cst
   set nocsverb
   " add any database in current directory
   if filereadable("cscope.out")
      cs add cscope.out
   " else add database pointed to by environment
   elseif $CSCOPE_DB != ""
      cs add $CSCOPE_DB
   endif
   set csverb
endif

" Switch syntax highlighting on, when the terminal has colors
" Also switch on highlighting the last used search pattern.
if &t_Co > 2 || has("gui_running")
  syntax on
  set hlsearch
endif

if &term=="xterm"
     set t_Co=8
     set t_Sb=[4%dm
     set t_Sf=[3%dm
endif


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" CSCOPE settings for vim           
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"
" This file contains some boilerplate settings for vim's cscope interface,
" plus some keyboard mappings that I've found useful.
"
" USAGE: 
" -- vim 6:     Stick this file in your ~/.vim/plugin directory (or in a
"               'plugin' directory in some other directory that is in your
"               'runtimepath'.
"
" -- vim 5:     Stick this file somewhere and 'source cscope.vim' it from
"               your ~/.vimrc file (or cut and paste it into your .vimrc).
"
" NOTE: 
" These key maps use multiple keystrokes (2 or 3 keys).  If you find that vim
" keeps timing you out before you can complete them, try changing your timeout
" settings, as explained below.
"
" Happy cscoping,
"
" Jason Duell       jduell@alumni.princeton.edu     9/12/2001
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""


" This tests to see if vim was configured with the '--enable-cscope' option
" when it was compiled.  If it wasn't, time to recompile vim... 
if has("cscope")

    """"""""""""" Standard cscope/vim boilerplate

    " use both cscope and ctag for 'ctrl-]', ':ta', and 'vim -t'
    set cscopetag

    " check cscope for definition of a symbol before checking ctags: set to 1
    " if you want the reverse search order.

    " show msg when any other cscope db added
	set cscopeverbose  

    """"""""""""" My cscope/vim key mappings
    "
    " The following maps all invoke one of the following cscope search types:
    "
    "   's'   symbol: find all references to the token under cursor
    "   'g'   global: find global definition(s) of the token under cursor
    "   'c'   calls:  find all calls to the function name under cursor
    "   't'   text:   find all instances of the text under cursor
    "   'e'   egrep:  egrep search for the word under cursor
    "   'f'   file:   open the filename under cursor
    "   'i'   includes: find files that include the filename under cursor
    "   'd'   called: find functions that function under cursor calls
    "
    " Below are three sets of the maps: one set that just jumps to your
    " search result, one that splits the existing vim window horizontally and
    " diplays your search result in the new window, and one that does the same
    " thing, but does a vertical split instead (vim 6 only).
    "
    " I've used CTRL-\ and CTRL-@ as the starting keys for these maps, as it's
    " unlikely that you need their default mappings (CTRL-\'s default use is
    " as part of CTRL-\ CTRL-N typemap, which basically just does the same
    " thing as hitting 'escape': CTRL-@ doesn't seem to have any default use).
    " If you don't like using 'CTRL-@' or CTRL-\, , you can change some or all
    " of these maps to use other keys.  One likely candidate is 'CTRL-_'
    " (which also maps to CTRL-/, which is easier to type).  By default it is
    " used to switch between Hebrew and English keyboard mode.
    "


    " To do the first type of search, hit 'CTRL-\', followed by one of the
    " cscope search types above (s,g,c,t,e,f,i,d).  The result of your cscope
    " search will be displayed in the current window.  You can use CTRL-T to
    " go back to where you were before the search.  
    "

    nmap <C-\>s :cs find s <C-R>=expand("<cword>")<CR><CR>	
    nmap <C-\>g :cs find g <C-R>=expand("<cword>")<CR><CR>	
    nmap <C-\>c :cs find c <C-R>=expand("<cword>")<CR><CR>	
    nmap <C-\>t :cs find t <C-R>=expand("<cword>")<CR><CR>	
    nmap <C-\>e :cs find e <C-R>=expand("<cword>")<CR><CR>	
    nmap <C-\>f :cs find f <C-R>=expand("<cfile>")<CR><CR>	
    nmap <C-\>i :cs find i <C-R>=expand("<cfile>")<CR><CR>	
    nmap <C-\>d :cs find d <C-R>=expand("<cword>")<CR><CR>	


    " Using 'CTRL-spacebar' (intepreted as CTRL-@ by vim) then a search type
    " makes the vim window split horizontally, with search result displayed in
    " the new window.
    "
    " (Note: earlier versions of vim may not have the :scs command, but it
    " can be simulated roughly via:
    "    nmap <C-@>s <C-W><C-S> :cs find s <C-R>=expand("<cword>")<CR><CR>	

    nmap <C-@>s :scs find s <C-R>=expand("<cword>")<CR><CR>	
    nmap <C-@>g :scs find g <C-R>=expand("<cword>")<CR><CR>	
    nmap <C-@>c :scs find c <C-R>=expand("<cword>")<CR><CR>	
    nmap <C-@>t :scs find t <C-R>=expand("<cword>")<CR><CR>	
    nmap <C-@>e :scs find e <C-R>=expand("<cword>")<CR><CR>	
    nmap <C-@>f :scs find f <C-R>=expand("<cfile>")<CR><CR>	
    nmap <C-@>i :scs find i <C-R>=expand("<cfile>")<CR><CR>	
    nmap <C-@>d :scs find d <C-R>=expand("<cword>")<CR><CR>	


    " Hitting CTRL-space *twice* before the search type does a vertical 
    " split instead of a horizontal one (vim 6 and up only)

    nmap <C-@><C-@>s :vert scs find s <C-R>=expand("<cword>")<CR><CR>	
    nmap <C-@><C-@>g :vert scs find g <C-R>=expand("<cword>")<CR><CR>	
    nmap <C-@><C-@>c :vert scs find c <C-R>=expand("<cword>")<CR><CR>	
    nmap <C-@><C-@>t :vert scs find t <C-R>=expand("<cword>")<CR><CR>	
    nmap <C-@><C-@>e :vert scs find e <C-R>=expand("<cword>")<CR><CR>	
    nmap <C-@><C-@>f :vert scs find f <C-R>=expand("<cfile>")<CR><CR>	
    nmap <C-@><C-@>i :vert scs find i <C-R>=expand("<cfile>")<CR><CR>	
    nmap <C-@><C-@>d :vert scs find d <C-R>=expand("<cword>")<CR><CR>	


    """"""""""""" key map timeouts
    "
    " By default Vim will only wait 1 second for each keystroke in a mapping.
    " You may find that too short with the above typemaps.  If so, you should
    " either turn off mapping timeouts via 'notimeout'.
    "
    "set notimeout 
    "
    " Or, you can keep timeouts, by uncommenting the timeoutlen line below,
    " with your own personal favorite value (in milliseconds):
    "
    "set timeoutlen=4000
    "
    " Either way, since mapping timeout settings by default also set the
    " timeouts for multicharacter 'keys codes' (like <F1>), you should also
    " set ttimeout and ttimeoutlen: otherwise, you will experience strange
    " delays as vim waits for a keystroke after you hit ESC (it will be
    " waiting to see if the ESC is actually part of a key code like <F1>).
    "
    "set ttimeout 
    "
    " personally, I find a tenth of a second to work well for key code
    " timeouts. If you experience problems and have a slow terminal or
    " network connection, set it higher.  If you don't set ttimeoutlen, the
    " value for timeoutlent (default: 1000) is used.
    "
    "set ttimeoutlen=100

endif


" set spacebar to toggle between windows
:map <Space> <C-W><C-W>
:map + <C-W>+
:map - <C-W>-

" Toggle highlighting tabs in both Normal and Insert modes.
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"
" Set the highlight for tabs
"highlight WhitespaceTabs ctermbg=4 guibg=4
"
" Build a vim command to match tabs
let s:tab_matcher = 'match WhitespaceTabs /\t/'
"
" Create a function to toggle tab checking
"
function! TabsCheck ()
	let g:check_tabs = exists('g:check_tabs') ? !g:check_tabs : 1
	if g:check_tabs
		highlight WhitespaceTabs ctermbg=blue guibg=blue
		exec s:tab_matcher
	"	highlight WhitespaceEOL ctermbg=red guibg=red
	"	match WhitespaceEOL /\s\+$/
	else
	"	highlight WhitespaceTabs ctermbg=1 guibg=0
	"	exec s:tab_matcher
		" set nohlsearch
		highlight WhitespaceEOL ctermbg=red guibg=red
		match WhitespaceEOL /\s\+$/
	endif
endfunction

inoremap <F4> <c-o>:call TabsCheck()<CR>
noremap <F4> :call TabsCheck()<CR>
" nmap <F4> :match WhitespaceTabs /\t/<CR>
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Set wrap on and off in both Normal and Insert modes.
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

set linebreak
function! HyperWrap ()
	let g:wrapping = exists('g:wrapping') ? !g:wrapping : 1
	if g:wrapping
		" When wrap is on ....
		" use  g w a p  in normal mode to reformat a paragraph
		set textwidth=75
		set wrapmargin=75
		set wrap
	else
		set textwidth=0
		set wrapmargin=0
		set nowrap
	endif
endfunction

inoremap <F6> <c-o>:call HyperWrap()<CR>
noremap <F6> :call HyperWrap()<CR>
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Change PreProc color for easier viewing in dark background
highlight PreProc term=underline cterm=bold ctermfg=5

" Toggle paste mode using F3 key
set pastetoggle=<F3>

" Set vertical for diff mode
set diffopt=vertical

" USe smartcase for searches. Searches will be case-insensitive, unless
" there is an uppercase letter in the search pattern.
set ignorecase smartcase

" Use ctrl-s to save while editing in insert mode.
inoremap <c-w> <c-o>:update<CR>
noremap <c-w> :update<CR>

" Use ctrl-x to quit from insert mode.
inoremap <c-x> <esc>:quit<CR>
noremap <c-x> :quit<CR>

" Shift-Enter to add a line below from Normal mode
"map <S-Enter> O<Esc>j
" map <S-Enter> O<Esc>

" Enter to add a line from normal mode.
" map <CR> o<Esc>k
"map <CR> o<Esc>

" Show lines greater than 80 columns
:match ErrorMsg '\%>80v.\+'

" Highlight whitespace at the end of a line
highlight WhitespaceEOL ctermbg=red guibg=red
match WhitespaceEOL /\s\+$/

" Make it easier to see matches on a dark background.
hi search term=reverse term=bold ctermbg=5 ctermfg=2

" List buffers to choose for editing
:nnoremap <F5> :buffers<CR>:buffer<Space>
:inoremap <c-o><F5> :buffers<CR>:buffer<Space>

" My signature
noremap <F12>a<CR>Acked-by: Tony Camuso <tcamuso@redhat.com><CR>
inoremap <F12> <c-o>a<CR>Acked-by: Tony Camuso <tcamuso@redhat.com><CR>

noremap <F9>a<CR>Series<CR>Acked-by: Tony Camuso <tcamuso@redhat.com><CR>
inoremap <F9> <c-o>a<CR>Series<CR>Acked-by: Tony Camuso <tcamuso@redhat.com><CR>

com! -nargs=1 -range Sbak call MoveSelectedLinesToFile(<f-args>)
fun! MoveSelectedLinesToFile(filename)
    exec "'<,'>w! >>" . a:filename
    norm gvd
endfunc
":noremap <F7>Sbak<CR>
":inoremap <F7><c-o>Sbak<CR>

nnoremap <F8> :setl noai nocin nosi inde=<CR>

" Pathogen
execute pathogen#infect()
call pathogen#helptags() " generate helptags for everything in ‘runtimepath’
syntax on
filetype plugin indent on

" autocmd vimenter * NERDTree
