
" add possibility to
"
" - add 'force' argument to MixCompile command for full project recompile to
"   see all warnings
"
" - run ExUnit test and parse output
"   x compile errors
"   - test failure - receive/refute assert fails
"   x test failure - assert fail
"   x test failure - GenServer crash
"   x test failure - other???
"   - sort tests in output disregarding ExUnits shuffling
"
"   instead of using quickfix - use more graphical UI
" - show symbols for failed tests using signs functionality
"   - shortcuts to navigate failed tests list (yes, load back to qf window) +
"     also if there are splits visible - just to correct window, if possible;
"     do not switch buffer
" - shortcut to see current test's full fail message in preview window 
"       :help special-buffers
"
" - command to rerun last test
" - shortcuts for running tests + rerun (in Vim-Elixir-IDE)
" - run all test files from current directory
" - fix absolute paths being visible in :copen, use short ones
" x run all test suite/current test file/test under cursor
"
"   only in Vim8.0 with jobs support
"
" - start/reconnect to xterm for full output copy
" - load failed tests list from job/channel + show signs
" - kill jobs properly when changing target
" - allow async automatic recompile on each ex/exs save + show syntax
"   errors/warnings (like syntastic)
" - automatically rerun last test on saving any ex/exs file from current
"   project (send \n to watched process)
" 
" - notify in airline that there are compile errors
" - use async jobs for on-save compile/test runs (only Vim 8.x)
"   allow killing tests as soon as first error is received/parsed (run with
"   -seed 0 to have consistent sequence)
"
" replace cc/cn & etc with out replacements
" http://vim.wikia.com/wiki/Replace_a_builtin_command_using_cabbrev
" http://stackoverflow.com/questions/2605036/vim-redefine-a-command


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


let s:WATCHING_INACTIVE    = -999
let s:WATCHING_PID_UNKNOWN = -998
let s:MAKEPRG_MIX_RUN = 'mix test'

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
                \   '%D**CWD**%f,' .
                \  '%-G%\\s%#,'.
                \  '%-GSKIP,'.
                \  '%-GGenerated\ %.%#\ app,'.
                \  '%-GIncluding\ tags:%.%#,'.
                \  '%-GExcluding\ tags:%.%#,'.
                \  '%-GFinished\ in\ %.%#,'.
                \  '%-G\ \ \ \ \ stacktrace:,'.
                \     '**\ (%[A-Z]%\\w%\\+%trror)\ %f:%l:\ %m,'.
                \  '%+G\ \ \ \ \ %\\w%\\+:\ ,'.
                \   '%E\ \ %\\d%\\+)\ %m,' .
                \   '%Z\ \ \ \ \ %f:%l,'.
                \  '%+G\ \ \ \ \ %\\w%\\+,'.
                \     '%t\ \ \ \ \ \ %f:%l:\ %m,'.
                \ "",
            \ "exunit_run_orig":
                \  '%G\ \ %f:%.%#,'.
                \  '%-D**CWD**%f,' .
                \  "%-G**CWD**%f,".
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



function! vimelixirexunit#boot() " {{{
  call vimelixirexunit#setDefaults()

  if g:vim_elixir_mix_compile != ''  | call vimelixirexunit#setMixCompileCommand() | endif
  if g:vim_elixir_exunit_tests != '' | call vimelixirexunit#setExUnitRunCommands() | endif

  let s:XTERM_CAT_PID = s:WATCHING_INACTIVE
  let s:INPUT_CAT_PID = s:WATCHING_INACTIVE
  let s:MIX_TEST_JOB  = s:WATCHING_INACTIVE

endfunction " }}}

function! vimelixirexunit#setDefaults() "{{{
  if !exists('g:vim_elixir_exunit_shell')
      let g:vim_elixir_exunit_shell = &shell
  endif

  call s:setGlobal('g:vim_elixir_mix_compile', 1)
  call s:setGlobal('g:vim_elixir_exunit_tests', 1)

  " do not want to mess with windows async yet
  call s:setGlobal('g:vim_elixir_exunit_async', (v:version >= 800 && !(has("win32") || has("win16"))))

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

    command! -bar ExUnitWatchFile call vimelixirexunit#runExUnitWatchCommand('file')
    command! -bar ExUnitWatchLine call vimelixirexunit#runExUnitWatchCommand('line')

    map <silent> <buffer> <Leader>bb :ExUnitWatchLine<CR>
endfunction " }}}


" we have 3 modes of running this command
"
" 1) just run command in foreground once, block Vim for that time, then parse
"    output with errorformat and show errors (worst case, but if user requests
"    it:)
"
" 2) we do not have async support, but we can attach cat to mix test
" --listen-on-stdout and then write to cat command stdout using
"  /prod/$PID/fd/1 which will trigger test re-run (NOT IMPLEMENTED right now,
"  switch to Vim 8)
"
" 3) PROPER WAY:
"   - run xterm with just cat in it, no actual functionality there
"   - run background Job (mix test --listen-on-stdin) and connect to its
"   stdin/stdout
"   - when user saves file - send \n to mix test
"   - read all output of mix test and
"     - feed into quickfix with errorformat
"     - copy to stdin to xterm/cat, so that user will also see the real output
"
"   This mode can be also turned to nice, nonblocking mode 1, but much later :)
"
function s:getMakeprg(mode, mixDir)
    let mode = a:mode
    let mixCmd = s:MAKEPRG_MIX_RUN
    if mode == 'all'
        let makeprg = mixCmd
    elseif mode == 'file'
        let fileName = expand('%:p')
        let fileName = substitute(fileName, a:mixDir . '/', '', '')

        let makeprg = mixCmd . ' ' . escape(fileName, ' ')
    elseif mode == 'line'
        let fileName = expand('%:p')
        let fileName = substitute(fileName, a:mixDir . '/', '', '')

        let makeprg = mixCmd . ' ' . escape(fileName, ' ') . ':' . line('.')
    end

    return makeprg
endfunction

function! vimelixirexunit#runExUnitRunCommand(mode) " {{{
    let mixDir = vimelixirexunit#findMixDirectory()

    let makeprg = s:getMakeprg(a:mode, mixDir)

    let compilerDef = {
                \ 'makeprg': makeprg,
                \ 'target': 'qfkeep',
                \ 'cwd': mixDir,
                \ 'errorformat': s:ERROR_FORMATS['exunit_run'],
                \ 'postprocess': function('s:exUnitOutputPostprocess')
                \ }


    call s:runCompiler(compilerDef)
endfunction " }}}


function! s:exUnitOutputPostprocess(options, lines)
    if len(a:lines) < 2
        return a:lines
    endif

    let i = 0

    let ln = ''
    let hasNextLn = 1

    while (i<len(a:lines))
        let prevLn = ln
        let ln = a:lines[i]
        if ln =~ '^SKIP$'
            let pass = 1
           " do nothing
        elseif ln =~ '^     stacktrace:'
            if hasNextLn && prevLn =~ '^     [*][*]'
                let j = i+1
                while j<len(a:lines) && a:lines[j] !~ '^\s*$'
                    if a:lines[j] =~ '^       \S\+:\d\+: '
                        let a:lines[j] .= substitute(prevLn, ' \+', ' ', 'g')
                        break
                    endif
                    let j = j+1
                endwhile
                let a:lines[i-1] = ''
            endif

            let j = i+1
            while j<len(a:lines) && a:lines[j] !~ '^\s*$'
                if a:lines[j] =~ '^       \S\+:\d\+: '
                    let a:lines[j] = "E" . a:lines[j]
                endif
                let j += 1
            endwhile
        elseif ln =~ '^warning: '
            "TODO: may be it should be configurable from options, sometimes we
            "may want warnings

            "clean warning and lines afterwards
            let j = i
            while j<len(a:lines) && a:lines[j] !~ '^\s*$'
                let a:lines[j] = "SKIP"
                let j += 1
            endwhile
        elseif ln =~ '\C^[*][*] ([A-Z]\w\+Error) '
                let j = i+1
                " go forward and clean all consequetive ' (stdlib) file:line'
                " or similar messages
                while j<len(a:lines) && a:lines[j] !~ '^\s*$'
                    if a:lines[j] =~ '^    \+(\w\+) \S\+:\d\+:'
                        let a:lines[j] = "SKIP"
                    endif
                    let j += 1
                endwhile

        elseif ln =~ '^\C        \+\S\+:\d\+: [A-Z]\w*\.\w\+'
            if prevLn =~ '^         [*][*]'
                let a:lines[i] = "E" . ln . substitute(prevLn, ' \+', ' ', 'g')
                let j = i-1
                " go backwards and clean all consequetive '** (EXIT' or
                " similar messages
                while j>0 && a:lines[j] =~ '^      *[*][*] ('
                    let a:lines[j] = "SKIP"
                    let j -= 1
                endwhile
            else
                let a:lines[i] = "E" . ln
            endif
        elseif ln =~ '^\C       \+(\w\+) \S\+:\d\+: [:A-Z]\S\+/\d\+$'
            " skip error messages in system modules in stack trace
            let a:lines[i] = "SKIP"
        elseif ln =~ '^=ERROR REPORT'
            let j = i
            while j<len(a:lines) && a:lines[j] !~ '^\s*$'
                let a:lines[j] = ""
                let j += 1
            endwhile

        endif

        let i += 1
    endwhile

    return a:lines
endfunction

function vimelixirexunit#runExUnitWatchCommand(mode) " {{{
    let mixDir = vimelixirexunit#findMixDirectory()

    let run_compiler = 1
    let run_in_terminal = 0
    let mixCmd = 'mix test'
    if len(matches) == 1
        let mode = matches[0]
    else
        let mode = matches[1]
        let run_in_terminal = 1
        let mixCmd = 'mix test --color --listen-on-stdin'
    endif

    let makeprg = s:getMakeprg(a:mode)


    let terminal_cmd = makeprg
    let target = 'qfkeep'

    if g:vim_elixir_exunit_async && matches[0] == 'watch'
        " run make test in background, control it with sending \n when we
        " want to re-run test, attacht to output
        "
        " send copy of output to xterm so user can see it

        let mix_test_options = {
                    \ 'makeprg': makeprg,
                    \ 'target': target,
                    \ 'cwd': mixDir,
                    \ 'out_cb': function('vimelixirexunit#processJobOutput'),
                    \ 'errorformat': s:ERROR_FORMATS['exunit_run']
                    \ }

        call s:stopJob(s:MIX_TEST_JOB)
        call vimelixirexunit#parseJobOutput('reset', 0)

        let s:MIX_TEST_JOB = s:runJob(mix_test_options)

        let xterm_started = vimelixirexunit#findXTerm()

        if xterm_started
            " prevent double run on xterm with output
            let run_compiler = 0
        endif

        " we will later find `cat`'s pid and stdio by this string
        let terminal_cmd = 'cat - all_cats_are_gray_in_vim_exunit'
    else
        " just run mix test.watch inside terminal and we have no control
        " over it
        " TODO: actually we may try to use mkfifo to send \n to make it run
        " again, but screw it for now :)

        "let terminal_cmd = 'cat - input_cat_is_black | ' . terminal_cmd
        " tell laters script that we started with cat, but just do not know
        " PID yet
        "let s:INPUT_CAT_PID = s:WATCHING_PID_UNKNOWN
    endif

    if run_in_terminal
        let title = shellescape('ExUnit ' . expand('%:f'))
        let args  = g:vimide_terminal_run_args
        let args  = substitute(args, '%CMD%', shellescape(terminal_cmd), '')
        let args  = substitute(args, '%TITLE%', title, '')
        let target = 'ignore'

        let makeprg = g:vimide_terminal . ' ' . args . '&'
    endif

    if run_compiler
        let compilerDef = {
            \ 'makeprg': makeprg,
            \ 'target': target,
            \ 'cwd': mixDir,
            \ 'errorformat': s:ERROR_FORMATS['exunit_run']
            \ }

        let errors = s:runCompiler(compilerDef)
    endif
endfunction " }}}

function! vimelixirexunit#processJobOutput(options, msg)
    call vimelixirexunit#parseJobOutput(a:options, a:msg)
    call vimelixirexunit#postToXTerm(a:options, a:msg)
endfunction

function! vimelixirexunit#parseJobOutput(options, msg)
    if type(a:options) == 1 && a:options == 'reset'
        cexpr []
    else
        let options = deepcopy(a:options)
        let options['target'] = 'qfadd'
        call s:parseErrorLines(options, a:msg)
    endif
endfunction

function! vimelixirexunit#postToXTerm(options, msg)
    if vimelixirexunit#findXTerm()
        let xtermStdin = "/proc/" . s:XTERM_CAT_PID . "/fd/1"
        call s:appendToFile(a:msg, xtermStdin)
    endif
endfunction

function! vimelixirexunit#findXTerm()
    if s:XTERM_CAT_PID < 0
        let xterm_text = s:system("ps ax | grep '[0-9] cat - all_cats_are_gray_in_vim_exunit'")
        let xterm_msg = split(xterm_text, " ")

        if len(xterm_msg) > 2
            let s:XTERM_CAT_PID = xterm_msg[0]
        endif
    endif

    return s:XTERM_CAT_PID > 0
endfunction

function! s:appendToFile(message, file)
  new
  setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted
  put=a:message
  execute 'w >>' a:file
  q
endfun

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

    if has_key(a:options, 'postprocess')
        "debug let err_lines = a:options['postprocess'](a:options, err_lines)
        let err_lines = a:options['postprocess'](a:options, err_lines)
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
    elseif a:options['target'] =~ 'qfadd'
        caddexpr err_lines
        let errors = deepcopy(getqflist())
    elseif a:options['target'] =~ '^qf'
        cgetexpr err_lines
        let errors = deepcopy(getqflist())
    elseif a:options['target'] == 'ignore'
        " do nothing
        let errors = []
    endif

    if has_key(a:options, 'leave_valid')
        call filter(errors, "v:val['valid']")
    endif

    let &errorformat = old_errorformat
    let &l:errorformat = old_local_errorformat

    return errors
endfunction " }}}


function! s:runJob(options)
    " save options and locale env variables
    let old_cwd = getcwd()

    let options = deepcopy(a:options)

    if !has_key(options, 'target')
        let options['target'] = 'llist'
    endif

    if has_key(options, 'cwd')
        execute 'lcd ' . fnameescape(options['cwd'])
    endif

    " add exit callback later???
    let job_id = job_start(options['makeprg'], {
                \ 'in_io'      : 'pipe',
                \ 'out_io'     : 'pipe',
                \ 'in_mode'    : 'raw',
                \ 'out_mode'   : 'raw',
                \ 'stoponexit' : 'term',
                \ 'out_cb' : {ch, msg -> s:runJobCallback(options, ch, msg)}
                \ })

    if has_key(options, 'cwd')
        execute 'lcd ' . fnameescape(old_cwd)
    endif

    return job_id
endfunction

function! s:stopJob(job_id)
    " 9 is job type
    if type(a:job_id) == 9
        job_stop(a:job_id, "int")
        job_stop(a:job_id, "int")
    endif
endfunction

function! s:stopJobOnExit()
    " correctly cleanup 'mix test' job
    " it requires two SIGINT to clean child processes and does not like
    " SIGTERM
    call s:stopJob(s:MIX_TEST_JOB)
endfunction

function! s:runJobCallback(options, ch, msg)
    if has_key(a:options, 'out_cb')
        call a:options['out_cb'](a:options, a:msg)
    endif
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

    call s:revertQFLocationWindow(options)

    return errors
endfunction " }}}

function s:revertQFLocationWindow(options)
    if a:options['target'] == 'llist'
        try
            silent lolder
        catch /\m^Vim\%((\a\+)\)\=:E380/
            " E380: At bottom of quickfix stack
            call setloclist(0, [], 'r')
        catch /\m^Vim\%((\a\+)\)\=:E776/
            " E776: No location list
            " do nothing
        endtry
    elseif a:options['target'] == 'qf'
        try
            silent colder
        catch /\m^Vim\%((\a\+)\)\=:E380/
            " E380: At bottom of quickfix stack
            call setqflist(0, [], 'r')
        catch /\m^Vim\%((\a\+)\)\=:E776/
            " E776: No location list
            " do nothing
        endtry
    elseif a:options['target'] == 'qfkeep' || a:options['target'] == 'ignore'
        " no nothing
    endif
endfunction


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

    "let cmd_start = reltime()
    let out = system(a:command)
    "let cmd_time = split(reltimestr(reltime(cmd_start)))[0]

    let $LC_ALL = old_lc_all
    let $LC_MESSAGES = old_lc_messages

    let &shell = old_shell

    return out
endfunction "}}}

" solely for debug
let s:dump_error_content=''
function! ShowContent()
    echo s:dump_error_content
endfunction

function! vimelixirexunit#testParseErrorLines(formatType, content, valid) "{{{
    " utility API just to allow rspec
    let options = {
                \ "errorformat": s:ERROR_FORMATS[a:formatType],
                \ 'target': "llist",
                \ 'postprocess': function('s:exUnitOutputPostprocess'),
                \ 'leave_valid': a:valid
                \ }
    return s:parseErrorLines(options, a:content)
endfunction "}}}

augroup ElixirExUnit
    au!
    au VimLeave call s:stopJobOnExit()
augroup END

" vim: set sw=4 sts=4 et fdm=marker:
"
