

function! vimelixirexunit#boot()
  call vimelixirexunit#setDefaults()

  if g:vim_elixir_mix_compile != '' | call vimelixirexunit#setMixCompileCommand() | endif


endfunction

function! vimelixirexunit#setDefaults() "{{{
  if !exists('g:vim_elixir_exunit_shell')
      let g:vim_elixir_exunit_shell = &shell
  endif

  call s:setGlobal('g:vim_elixir_mix_compile', 1)
  "call s:setGlobal('g:vim_elixir_exunit_manage_indents', 1)
  "call s:setGlobal('g:vim_elixir_exunit_manage_search', 1)
  "call s:setGlobal('g:vim_elixir_exunit_manage_completition', 1)
endfunction "}}}

function vimelixirexunit#setMixCompileCommand()
    command! -bar EU call vimelixirexunit#runMixCompileCommand()
    map <Leader>aa :EU<CR>
endfunction 


function vimelixirexunit#runMixCompileCommand()

    let mixDir = vimelixirexunit#findMixDirectory()

    let compilerDef = {
        \ "makeprg": "mix compile",
        \ "cwd": mixDir,
        \ "errorformat": "\%E\ \ %n)\ %m"
        \ }

    let errors = s:runCompiler(compilerDef)
    debug echo "asd"

"let s:cpo_save = &cpo
"set cpo-=C
"CompilerSet makeprg=mix\ test
"CompilerSet errorformat=
"  \%E\ \ %n)\ %m,
"  \%+G\ \ \ \ \ **\ %m,
"  \%+G\ \ \ \ \ stacktrace:,
"  \%C\ \ \ \ \ %f:%l,
"  \%+G\ \ \ \ \ \ \ (%\\w%\\+)\ %f:%l:\ %m,
"  \%+G\ \ \ \ \ \ \ %f:%l:\ %.%#,
"  \**\ (%\\w%\\+)\ %f:%l:\ %m

"let &cpo = s:cpo_save
"unlet s:cpo_save

endfunction

function! vimelixirexunit#findMixDirectory()
    let fName = expand("%:p:h")

    while 1
        let mixFileName = fName . "/mix.exs"
        if file_readable(mixFileName)
            return fName
        endif

        let fNameNew = fnamemodify(fName, ":h")
        " after we reached top of heirarchy
        if fNameNew == fName
            return 0
        endif
        let fName = fNameNew
    endwhile
endfunction

function! vimelixirexunit#testParseErrorLines(format, content)
    return s:parseErrorLines({"errorformat": a:format}, a:content)
endfunction

function! s:parseErrorLines(options, content) " {{{
    let old_local_errorformat = &l:errorformat
    let old_errorformat = &errorformat
    
    if has_key(a:options, 'errorformat')
        let &errorformat = a:options['errorformat']
        set errorformat<
    endif

    let err_lines = split(a:content, "\n", 1)
    lgetexpr err_lines

    let errors = deepcopy(getloclist(0))

    let &errorformat = old_errorformat
    let &l:errorformat = old_local_errorformat
    
    return errors
endfunction " }}}


function! s:runCompiler(options) " {{{
    " save options and locale env variables {{{
    let old_cwd = getcwd()
    " }}}
    
    if has_key(a:options, 'cwd')
        execute 'lcd ' . fnameescape(a:options['cwd'])
    endif

    let error_content = s:system(a:options['makeprg'])

    if has_key(a:options, 'cwd')
        execute 'lcd ' . fnameescape(old_cwd)
    endif

    let errors = s:parseErrorLines(a:options, error_content)

    try
        silent lolder
    catch /\m^Vim\%((\a\+)\)\=:E380/
        " E380: At bottom of quickfix stack
        call setloclist(0, [], 'r')
    catch /\m^Vim\%((\a\+)\)\=:E776/
        " E776: No location list
        " do nothing
    endtry

    return errors
endfunction " }}}

function! s:setGlobal(name, default) " {{{
  if !exists(a:name)
    if type(a:name) == 0 || type(a:name) == 5
      exec "let " . a:name . " = " . a:default
    elseif type(a:name) == 1
      exec "let " . a:name . " = '" . escape(a:default, "\'") . "'"
    endif
  endif
endfunction " }}}

"command! -bar -nargs=* -complete=custom,s:CompleteCheckerName SyntasticCheck call SyntasticCheck(<f-args>)
"command! -bar -nargs=? -complete=custom,s:CompleteFiletypes   SyntasticInfo  call SyntasticInfo(<f-args>)
"command! -bar Errors              call SyntasticErrors()
"command! -bar SyntasticReset      call SyntasticReset()
"command! -bar SyntasticToggleMode call SyntasticToggleMode()
"command! -bar SyntasticSetLoclist call SyntasticSetLoclist()

"command! SyntasticJavacEditClasspath runtime! syntax_checkers/java/*.vim | SyntasticJavacEditClasspath
"command! SyntasticJavacEditConfig    runtime! syntax_checkers/java/*.vim | SyntasticJavacEditConfig


" Get the value of a Vim variable.  Allow local variables to override global ones.
function! s:rawVar(name, ...) abort " {{{2
    return get(b:, a:name, get(g:, a:name, a:0 > 0 ? a:1 : ''))
endfunction " }}}2

" Get the value of a syntastic variable.  Allow local variables to override global ones.
function! s:var(name, ...) abort " {{{2
    return call('s:rawVar', ['vim_elixir_exunit_' . a:name] + a:000)
endfunction " }}}2


function s:system(command) abort "{{{
    let old_shell = &shell
    let old_lc_messages = $LC_MESSAGES
    let old_lc_all = $LC_ALL

    let &shell = s:var('shell')
    let $LC_MESSAGES = 'C'
    let $LC_ALL = ''

    let cmd_start = reltime()
    let out = system(a:command)
    let cmd_time = split(reltimestr(reltime(cmd_start)))[0]

    let $LC_ALL = old_lc_all
    let $LC_MESSAGES = old_lc_messages

    let &shell = old_shell

    return out
endfunction "}}}



" vim: set sw=4 sts=4 et fdm=marker:
