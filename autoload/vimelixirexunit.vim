
" add possibility to
"
" - add 'force' argument to MixCompile command for full project recompile to
"   see all warnings
"
" - run ExUnit test and parse output
"   - compile error
"   - test failure - assert fail
"   - test failure - GenServer crash
"   - test failure - other???
" - show symbols for failing tests
" - shortcut to see current test's fail message
" - run all test suite/current test file/test under cursor
" - rerun last test
" - automatically rerun last test on saving any ex/exs file from current
"   project
"
"   only in Vim8.0 with jobs support
"
" - allow recompile on each ex/exs save
" - notify in airline that there are compile errors
" - use async jobs for on-save compile/test runs (only Vim 8.x)
"   allow killing tests as soon as first error is received/parsed (run with
"   -seed 0 to have consistent sequence)
"


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



"  1) test truth (A)
"     test/fixture_test.exs:3
"     Assertion with == failed
"     code: 2 == 1
"     lhs:  2
"     rhs:  1
"     stacktrace:
"       test/fixture_test.exs:4: (test)



"Finished in 0.05 seconds
"1 test, 1 failure

"Randomized with seed 669689


let s:ERROR_FORMATS = {
            \ "mix_compile":
                \'%-G%[\ ]%[\ ]%[\ ]%#(%.%#,'.
                \'%E**\ (%[A-Z]%[%^)]%#)\ %f:%l:\ %m,'.
                \'%Z%^%[\ ]%#%$,'.
                \'%W%>warning:\ %m,'.
                \'%-C\ \ %f:%l,'.
                \'%-G==\ Compilation error%.%#,'.
                \'%-G%[\ ]%#',
            \ "mix_compile_errors_only":
                \ "%-D**CWD**%f,".
                \'%-G==\ Compilation error%.%#,'.
                \'%-Gwarning:%.%#,'.
                \'%-G%[\ ]%#,'.
                \'%-G\ %.%#,'.
                \'%E**\ (%[%^)]%#)\ %f:%l:\ %m',
            \ "exunit_run":
                \  '%-D**CWD**%f,' .
                \  '%-G%\\s%#,'.
                \  '%-GGenerated\ %.%#\ app,'.
                \  '%-A=ERROR REPORT%.%#,'.
                \  '%-G**\ %\\S%.%#,'.
                \   '%Z\ %#,'.
                \ '%E%>\ \ %n)\ %m,' .
                \   '%C\ \ \ \ \ %f:%l,'.
                \  '%+C\ \ \ \ \ **\ %m,'.
                \ '%Z%>\ \ \ \ \ stacktrace:,'.
                \  '%+G\ \ \ \ \ %#**%.%#,'.
                \  '%+G\ \ \ \ \ %\\w%m,'.
                \   '%A\ \ \ \ \ \ %\\+(%\\w%\\+)\ %f:%l:\ %m,'.
                \   '%E\ \ \ \ \ \ %f:%l:\ %m,'.
                \'%-G%>warning:%.%#,'.
                \  '%-G\ \ %f:%.%#,'.
                \  '%-G\ \ \ \ \ %#%[[{(]%.%#,'.
                \  '%-G\ \ \ \ \ \ \ \ \ %#%[a-z]%.%#,'.
                \ ""
            \ }


                "\  '%-G\ \ \ \ \ %#%[[{(]%.%#,'.


" exunit_run
" load directory
" skip empty lines
"
"
"


                "\ "%C\ \ \ \ \ %f:%l,".
                "\ '%+G\ \ \ \ \ stacktrace:,'.
                "\ '%C\ \ \ \ \ \ \ %f:%l:%.%#,'.

function! vimelixirexunit#boot() " {{{
  call vimelixirexunit#setDefaults()

  if g:vim_elixir_mix_compile != ''  | call vimelixirexunit#setMixCompileCommand() | endif
  if g:vim_elixir_exunit_tests != '' | call vimelixirexunit#setExUnitRunCommands() | endif


endfunction " }}}

function! vimelixirexunit#setDefaults() "{{{
  if !exists('g:vim_elixir_exunit_shell')
      let g:vim_elixir_exunit_shell = &shell
  endif

  call s:setGlobal('g:vim_elixir_mix_compile', 1)
  call s:setGlobal('g:vim_elixir_exunit_tests', 1)

  "call s:setGlobal('g:vim_elixir_exunit_rerun_on_save', 1)
  "call s:setGlobal('g:vim_elixir_exunit_symbols', 1)

endfunction "}}}

" support MixCompile
function vimelixirexunit#setMixCompileCommand() " {{{
    let mixDir = vimelixirexunit#findMixDirectory()

    if mixDir != ''
        let &l:makeprg="cd ".escape(mixDir, " ").";".
                    \ "(echo '**CWD**".escape(mixDir, " ")."';".
                    \ "mix compile)"
        let &l:errorformat = s:ERROR_FORMATS['mix_compile_errors_only']
    endif

    command! -bar MixCompile call vimelixirexunit#runMixCompileCommand()
    map <silent> <buffer> <Leader>aa :MixCompile<CR>
endfunction " }}}

function vimelixirexunit#runMixCompileCommand() " {{{
    let mixDir = vimelixirexunit#findMixDirectory()

    let compilerDef = {
        \ "makeprg": "mix compile",
        \ "target": "qfkeep",
        \ "cwd": mixDir,
        \ "errorformat": s:ERROR_FORMATS['mix_compile']
        \ }

    let errors = s:runCompiler(compilerDef)
endfunction " }}}

" support ExUnitRun* commands
function vimelixirexunit#setExUnitRunCommands() " {{{
    let mixDir = vimelixirexunit#findMixDirectory()

    if mixDir != ''
        let &l:makeprg="cd ".escape(mixDir, " ").";".
                    \ "(echo '**CWD**".escape(mixDir, " ")."';".
                    \ "mix compile)"
        let &l:errorformat = s:ERROR_FORMATS['mix_compile_errors_only']
    endif

    command! -bar ExUnitRunAll call vimelixirexunit#runExUnitRunCommand('all')
    command! -bar ExUnitRunFile call vimelixirexunit#runExUnitRunCommand('file')
    command! -bar ExUnitRunLine call vimelixirexunit#runExUnitRunCommand('line')

    command! -bar ExUnitWatchFile call vimelixirexunit#runExUnitRunCommand('watch/file')
    command! -bar ExUnitWatchLine call vimelixirexunit#runExUnitRunCommand('watch/line')

    map <silent> <buffer> <Leader>bb :ExUnitRunAll<CR>
endfunction " }}}


function vimelixirexunit#runExUnitRunCommand(mode) " {{{
    let mixDir = vimelixirexunit#findMixDirectory()

    let makeprg = ''

    let matches = split(a:mode, '/')

    let run_in_terminal = 0
    let mix_cmd = 'mix test'
    if len(matches) == 1
        let mode = matches[0]
    else
        let mode = matches[1]
        let run_in_terminal = 1
        let mix_cmd = 'mix test.watch'
    endif

    if mode == 'all'
        let makeprg = mix_cmd
    elseif mode == 'file'
        let fileName = expand('%:p')
        let fileName = substitute(fileName, mixDir . '/', '', '')

        let makeprg = mix_cmd . ' ' . escape(fileName, ' ')
    elseif mode == 'line'
        let fileName = expand('%:p')
        let fileName = substitute(fileName, mixDir . '/', '', '')

        let makeprg = mix_cmd . ' ' . escape(fileName, ' ') . ':' . line('.')
    end

    if run_in_terminal
        let title = shellescape('ExUnit ' . expand('%:f'))
        let args  = g:vimide_terminal_run_args
        let args  = substitute(args, '%CMD%', shellescape(makeprg), '')
        let args  = substitute(args, '%TITLE%', title, '')

        let makeprg = g:vimide_terminal . ' ' . args . '&'
    endif

    let compilerDef = {
        \ 'makeprg': makeprg,
        \ 'target': 'qfkeep',
        \ 'cwd': mixDir,
        \ 'errorformat': s:ERROR_FORMATS['exunit_run']
        \ }

    let errors = s:runCompiler(compilerDef)
endfunction " }}}

function! vimelixirexunit#findMixDirectory() "{{{
    let fName = expand("%:p:h")

    while 1
        let mixFileName = fName . "/mix.exs"
        if file_readable(mixFileName)
            return fName
        endif

        let fNameNew = fnamemodify(fName, ":h")
        " after we reached top of heirarchy
        if fNameNew == fName
            return ''
        endif
        let fName = fNameNew
    endwhile
endfunction "}}}

function! s:parseErrorLines(options, content) " {{{
    let old_local_errorformat = &l:errorformat
    let old_errorformat = &errorformat

    let err_lines = split(a:content, "\n", 1)

    let err_format = ''
    if has_key(a:options, 'errorformat')
        let err_format = a:options['errorformat']
    endif

    if has_key(a:options, 'cwd')
        " hack to make path resolving work correctly
        " output and search pattern prepended with absolute directory path
        call insert(err_lines, "**CWD**".escape(a:options['cwd'], ' ')."\n")
        if err_format != ''
            let err_format = "%-D**CWD**%f,".err_format
        endif
    endif

    if err_format != ''
        let &errorformat = err_format
        set errorformat<
    endif

    if a:options['target'] == 'llist'
        lgetexpr err_lines
        let errors = deepcopy(getloclist(0))
    elseif a:options['target'] =~ '^qf'
        cgetexpr err_lines
        let errors = deepcopy(getqflist())
    endif

    if has_key(a:options, 'leave_valid')
        call filter(errors, "v:val['valid']")
    endif

    let &errorformat = old_errorformat
    let &l:errorformat = old_local_errorformat

    return errors
endfunction " }}}

" solely for debug
let s:dump_error_content=''
function! ShowContent()
    echo s:dump_error_content
endfunction

function! s:runCompiler(options) " {{{
    " save options and locale env variables
    let old_cwd = getcwd()

    let options = deepcopy(a:options)

    if !has_key(options, 'target')
        let options['target'] = 'llist'
    endif

    if has_key(options, 'cwd')
        execute 'lcd ' . fnameescape(options['cwd'])
    endif

    let error_content = s:system(options['makeprg'])

    if has_key(options, 'cwd')
        execute 'lcd ' . fnameescape(old_cwd)
    endif

    let s:dump_error_content=error_content

    let errors = s:parseErrorLines(options, error_content)

    if options['target'] == 'llist'
        try
            silent lolder
        catch /\m^Vim\%((\a\+)\)\=:E380/
            " E380: At bottom of quickfix stack
            call setloclist(0, [], 'r')
        catch /\m^Vim\%((\a\+)\)\=:E776/
            " E776: No location list
            " do nothing
        endtry
    elseif options['target'] == 'qf'
        try
            silent colder
        catch /\m^Vim\%((\a\+)\)\=:E380/
            " E380: At bottom of quickfix stack
            call setqflist(0, [], 'r')
        catch /\m^Vim\%((\a\+)\)\=:E776/
            " E776: No location list
            " do nothing
        endtry
    elseif options['target'] == 'qfkeep'
        " no nothing
    endif

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
function! s:rawVar(name, ...) abort " {{{
    return get(b:, a:name, get(g:, a:name, a:0 > 0 ? a:1 : ''))
endfunction " }}}

" Get the value of a syntastic variable.  Allow local variables to override global ones.
function! s:var(name, ...) abort " {{{
    return call('s:rawVar', ['vim_elixir_exunit_' . a:name] + a:000)
endfunction " }}}


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


function! vimelixirexunit#testParseErrorLines(formatType, content) "{{{
    " utility API just to allow rspec
    let options = {
                \ "errorformat": s:ERROR_FORMATS[a:formatType],
                \ 'target': "llist",
                \ 'leave_valid': 0
                \ }
    return s:parseErrorLines(options, a:content)
endfunction "}}}

" vim: set sw=4 sts=4 et fdm=marker:
"
