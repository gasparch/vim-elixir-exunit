
" Vim-Elixir-ExUnit allows tight integration of ExUnit framework with Vim
"
" (items with 'x' are done)
" TODO:
"
" - navigation
"   x jump between source/test files (open, hsplit, vsplit, force_dirs) (\xt, \xs, \xv, \x!)
"   - allow creation of test file from template (get module name with
"     alchemist.vim and fill in)
"
" - compiler support
"   x :make runs and shows only compile time errors
"   - :MixCompile shows errors and warnings
"       x add 'force' argument to MixCompile command for full project recompile to
"         see all warnings
"       x restore warnings capture + tests
"       x add shortcuts to calls: compile, compile all (\xc, \x!)
"       - fix absolute paths being visible in :copen, use short ones
"         (reproduce&write spec)
"
" - run ExUnit test and parse output (write rspec tests)
"   x compile errors
"   - test failure - receive/refute assert fails
"   x test failure - assert fail
"   x test failure - GenServer crash
"   x test failure - other???
"   x run tests from top to down (run mix test --seed 0)
"   - make possible to run ExUnit tests shuffled??? (or let user run from
"     commandline if it is really the case) (may be make configurable)
" x command to rerun last test
" x shortcuts for running tests - all,file,line,rerun  (<Leader>xa, xf, xl, xx)
" - move shortcuts to Vim-Elixir-IDE
" x run all test suite/current test file/test under cursor
" x convert error/warning navigation shortcuts to function calls and try to
"   make sense of warning/error message and navigate to correct column in the
"   line ([e/]e work like that, :cnext, cprev left unchanged)
"   x support 2 errors/warnings on same line
"   - support more than 2 errors/warnings on same line
"
" HIGH: only in Vim8.0 with jobs support
"
" x start xterm/reconnect to xterm for full output copy
" x use async jobs for on-save compile/test runs (only Vim 8.x)
" x load failed tests list from job/channel into QuickFix
" - show signs for failed jobs
"   - load failed tests list from job/channel into internal list/no QuickFix
" x kill jobs properly when changing target
" x automatically rerun last test on saving any ex/exs file from current
"   project (send \n to watched process)
"
" - show syntax errors/warnings on auto-save and recompile (like syntastic)
" - notify in airline that there are compile errors
" - allow killing tests as soon as first error is received/parsed (run with
"   -seed 0 to have consistent sequence)
"
" LOW: priority
" - run all test files from current directory
"
" LOW: priority for Vim 7.4 mode
"   instead of using quickfix - use more graphical UI
" - show symbols for failed tests using signs functionality
"   - shortcuts to navigate failed tests list (yes, load back to qf window) +
"     also if there are splits visible - just to correct window, if possible;
"     do not switch buffer
" - shortcut to see current test's full fail message in preview window
"       :help special-buffers
"
"
" we have 3 modes of running RunCommand/WatchCommand
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

let s:BOOT_FINISHED = 0

function! vimelixirexunit#boot() " {{{
  " TODO: move into if below?
  call vimelixirexunit#setDefaults()

  if !s:BOOT_FINISHED
      call vimelixirexunit#bootGlobal()
      let s:BOOT_FINISHED = 1
  endif

  " this happens in each buffer
  if g:vim_elixir_mix_compile     | call vimelixirexunit#setMixCompileCommand() | endif
  if g:vim_elixir_exunit_tests    | call vimelixirexunit#setExUnitRunCommands() | endif
  if g:vim_elixir_exunit_autofind | call vimelixirexunit#setExUnitAutofind()    | endif
endfunction " }}}

function! vimelixirexunit#setDefaults() "{{{
  if !exists('g:vim_elixir_exunit_shell')
      let g:vim_elixir_exunit_shell = &shell
  endif

  call s:setGlobal('g:vim_elixir_mix_compile', 1)
  call s:setGlobal('g:vim_elixir_exunit_tests', 1)

  " do not want to mess with windows async yet
  call s:setGlobal('g:vim_elixir_exunit_async', (v:version >= 800 && !(has("win32") || has("win16"))))

  call s:setGlobal('g:vim_elixir_exunit_rerun_on_save', 1)
  call s:setGlobal('g:vim_elixir_exunit_autofind', 1)

  "call s:setGlobal('g:vim_elixir_exunit_symbols', 1)

endfunction "}}}

function! vimelixirexunit#bootGlobal() " {{{
  let s:WATCHING_INACTIVE    = -999
  let s:WATCHING_PID_UNKNOWN = -998
  let s:MAKEPRG_MIX_RUN = 'mix test --seed 0 '

  let s:XTERM_CAT_PID = s:WATCHING_INACTIVE
  let s:INPUT_CAT_PID = s:WATCHING_INACTIVE
  let s:MIX_TEST_JOB  = s:WATCHING_INACTIVE

  " {{{ ERROR_FORMATS definition
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
                \ ""
              \ }
  " }}}
endfunction " }}}

function vimelixirexunit#setExUnitAutofind() " {{{
    let mixDir = vimelixirexunit#findMixDirectory()

    command! -bang -nargs=? -buffer ExUnitSwitchBetween call vimelixirexunit#runExUnitAutofind('<bang>', '<args>')

    map <buffer> <Leader>tt :ExUnitSwitchBetween<CR>
    map <buffer> <Leader>t! :ExUnitSwitchBetween!<CR>
    map <buffer> <Leader>ts :ExUnitSwitchBetween split<CR>
    map <buffer> <Leader>tv :ExUnitSwitchBetween vsplit<CR>
endfunction " }}}

" automatically finds corresponding source or test file
function vimelixirexunit#runExUnitAutofind(bang, mode) " {{{
    let mixDir = vimelixirexunit#findMixDirectory()

    " save options and locale env variables
    let old_cwd = getcwd()
    execute 'lcd ' . fnameescape(mixDir)

    " relative file name
    let fileName = expand('%:.')
    let shortName = expand('%:t:r')

    let openFile = ''
    let mkDir = ''

    " TODO: extract if clauses to separate function, they are exactly the same
    if fileName =~ '^lib/.*\.ex$'
        let testName = shortName . '_test.exs'
        let prefixDir = fnamemodify(fileName, ":h:s?lib/??")

        " no files found, force open of new one
        let openFile = 'test/'.prefixDir.'/'.testName

        if !filereadable(openFile)
            let files = glob('test/**/'.testName, 1, 1)
            if len(files) == 1
                " we found exact match
                let openFile = files[0]
            elseif len(files) == 0 && a:bang == '!'
                let mkDir = 'test/'.prefixDir
            else
                " we found several tests with same name
                " and they do not follow dir structure of the source
                " ignore for now
                let openFile = ''
            endif
        endif
    elseif fileName =~ '^test/.*_test\.exs$'
        let srcName = fnamemodify(shortName, ':s?_test??') . '.ex'
        let prefixDir = fnamemodify(fileName, ":h:s?test/??")

        " no files found, force open of new one
        let openFile = "lib/".prefixDir."/".srcName
        if !filereadable(openFile)
            let files = glob('lib/**/'.srcName, 1, 1)
            if len(files) == 1
                " we found exact match
                let openFile = files[0]
            elseif len(files) == 0 && a:bang == '!'
                let mkDir = 'lib/'.prefixDir
            else
                " we found several sources with same name
                " and they do not follow dir structure of the test
                " ignore for now
                let openFile = ''
            endif
        endif
    end

    if a:mode == ''
        let openCmd = 'e'
    elseif a:mode == 'split'
        let openCmd = 'sp'
    elseif a:mode == 'vsplit'
        let openCmd = 'vs'
    else
        return
    endif

    if openFile != ''
        "let openFile = fnamemodify(openFile, ':p')
        if mkDir != ''
            call mkdir(mkDir, 'p')
        endif
        let openFile = fnamemodify(openFile, ':~:.')
        execute openCmd . ' ' . fnameescape(openFile)

        execute 'lcd ' . fnameescape(old_cwd)
    else
        execute 'lcd ' . fnameescape(old_cwd)
    endif



endfunction " }}}

" support MixCompile
function vimelixirexunit#setMixCompileCommand() " {{{
    let mixDir = vimelixirexunit#findMixDirectory()

    if mixDir != ''
        " classic :make will parse/show only errors
        let &l:makeprg="cd ".escape(mixDir, " ").";".
                    \ "(echo '**CWD**".escape(mixDir, " ")."';".
                    \ "mix compile)"
        let &l:errorformat = s:ERROR_FORMATS['mix_compile_errors_only']
    endif

    command! -bang -buffer MixCompile call vimelixirexunit#runMixCompileCommand('<bang>')
    command! -buffer MixCompileAll call vimelixirexunit#runMixCompileCommand('!')

    map <buffer> <Leader>xc :MixCompile<CR>
    map <buffer> <Leader>x! :MixCompile!<CR>
endfunction " }}}

function! vimelixirexunit#runMixCompileCommand(arg) " {{{
    let mixDir = vimelixirexunit#findMixDirectory()

    let makeprg = 'mix compile'
    if a:arg == '!'
        let makeprg .= ' --force'
    endif

    let compilerDef = {
        \ 'makeprg': makeprg,
        \ 'target': 'qfkeep',
        \ 'cwd': mixDir,
        \ 'errorformat': s:ERROR_FORMATS['mix_compile']
        \ }

    let errors = s:runCompiler(compilerDef)
endfunction " }}}

" support ExUnitRun* commands, classic QuickFix workflow
" blocks Vim while running
function vimelixirexunit#setExUnitRunCommands() " {{{
    let mixDir = vimelixirexunit#findMixDirectory()

    if mixDir != ''
        let &l:makeprg="cd ".escape(mixDir, " ").";".
                    \ "(echo '**CWD**".escape(mixDir, " ")."';".
                    \ "mix compile)"
        let &l:errorformat = s:ERROR_FORMATS['mix_compile_errors_only']
    endif

    command! -bar ExUnitQfRunAll   call vimelixirexunit#runExUnitRunCommand('all')
    command! -bar ExUnitQfRunFile  call vimelixirexunit#runExUnitRunCommand('file')
    command! -bar ExUnitQfRunLine  call vimelixirexunit#runExUnitRunCommand('line')
    command! -bar ExUnitQfRerun    call vimelixirexunit#runExUnitRunCommand('run_again')

    command! -bar ExUnitWatchAll   call vimelixirexunit#runExUnitWatchCommand('all')
    command! -bar ExUnitWatchFile  call vimelixirexunit#runExUnitWatchCommand('file')
    command! -bar ExUnitWatchLine  call vimelixirexunit#runExUnitWatchCommand('line')
    command! -bar ExUnitWatchRerun call vimelixirexunit#runExUnitWatchCommand('run_again')
    command! -bar ExUnitWatchStop  call vimelixirexunit#runExUnitWatchCommand('stop')

    map <buffer> <Leader>xa :ExUnitQfRunAll<CR>
    map <buffer> <Leader>xf :ExUnitQfRunFile<CR>
    map <buffer> <Leader>xl :ExUnitQfRunLine<CR>
    " consider binding this in all buffers, not only in Elixir ones, for
    " easier access
    map <buffer> <Leader>xx :ExUnitQfRerun<CR>

    map <buffer> <Leader>wa :ExUnitWatchAll<CR>
    map <buffer> <Leader>wf :ExUnitWatchFile<CR>
    map <buffer> <Leader>wl :ExUnitWatchLine<CR>
    map <buffer> <Leader>ww :ExUnitWatchRerun<CR>
    " both Stop and Cancel mnomonics mapped to stop
    map <buffer> <Leader>ws :ExUnitWatchStop<CR>
    map <buffer> <Leader>wc :ExUnitWatchStop<CR>

    command! ExUnitNextError call s:navigateQuickFix('next')
    command! ExUnitPrevError call s:navigateQuickFix('prev')

    " jump to next/previous error and center screen
    " TODO: convert to functions for navigation to correct column
    nnoremap [e :ExUnitPrevError<CR>
    nnoremap ]e :ExUnitNextError<CR>
    " always open at bottom of screen, even if splits exist
    " we need full width to show long messages nicely
    cabbrev cw <c-r>=(getcmdtype()==':' && getcmdpos()==1 ? 'botright cwindow' : 'cw')<CR>

endfunction " }}}

function s:getMakeprg(mode, mixDir, mixCmd) " {{{
    if a:mode == 'all'
        let makeprg = a:mixCmd
    elseif a:mode == 'file'
        let fileName = expand('%:p')
        let fileName = substitute(fileName, a:mixDir . '/', '', '')

        let makeprg = a:mixCmd . ' ' . escape(fileName, ' ')
    elseif a:mode == 'line'
        let fileName = expand('%:p')
        let fileName = substitute(fileName, a:mixDir . '/', '', '')

        let makeprg = a:mixCmd . ' ' . escape(fileName, ' ') . ':' . line('.')
    end

    return makeprg
endfunction " }}}

let s:runExUnitRunCommandCache = ''
function! vimelixirexunit#runExUnitRunCommand(mode) " {{{
    let mixDir = vimelixirexunit#findMixDirectory()

    if a:mode == 'run_again'
        if s:runExUnitRunCommandCache != ''
            let makeprg = s:runExUnitRunCommandCache
        else
            call s:echoDull("No previous command to run tests.")
            return
        endif
    else
        let makeprg = s:getMakeprg(a:mode, mixDir, s:MAKEPRG_MIX_RUN)
        let s:runExUnitRunCommandCache = makeprg
    endif

    let compilerDef = {
                \ 'makeprg': makeprg,
                \ 'target': 'qfkeep',
                \ 'cwd': mixDir,
                \ 'errorformat': s:ERROR_FORMATS['exunit_run'],
                \ 'postprocess': function('s:exUnitOutputPostprocess')
                \ }

    let errors = s:runCompiler(compilerDef)
    call s:echoPassFailMessages(errors)
endfunction " }}}

function! s:echoPassFailMessages(errors, ...) " {{{
    let supress_compile_status = 0
    if a:0 == 1
        let supress_compile_status = a:1
    endif

    let tests_string = filter(deepcopy(a:errors), "v:val['text'] =~ '^\\d\\+ tests'")
    try
        if len(tests_string) > 0
            let tests_split = split(tests_string[0]['text'])

            if tests_split[2] > 0
                call s:echoWarning("Tests FAIL " . (tests_string[0]['text']))
            else
                cexpr []
                cclose
                call s:echoInfoText("Tests PASS")
            endif
        else
            if !supress_compile_status
                call s:echoWarning("Compile errors (most probably, didn't parsed them carefully :).")
            endif
        endif
    catch
        " do nothing
        let pass = 1
    endtry
endfunction " }}}

" convert ExUnit output to something more suited for errorformat parsing
function! s:exUnitOutputPostprocess(options, lines) " {{{
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
endfunction " }}}

let s:runExUnitWatchCommandCache = ''
let s:runExUnitWatchProjectDir = ''
function vimelixirexunit#runExUnitWatchCommand(mode) " {{{
    if !g:vim_elixir_exunit_async
        call s:echoDull("Async mode in not enabled or not supported (requires Vim8), sorry :( .")
        retur
    endif

    if a:mode == 'stop'
        let is_running = type(s:MIX_TEST_JOB) == 8 && job_status(s:MIX_TEST_JOB) == 'run'
        if is_running
            call s:stopJob(s:MIX_TEST_JOB)
            let s:MIX_TEST_JOB = s:WATCHING_INACTIVE
            call s:echoNormal("Watch job stopped.")
        else
            call s:echoNormal("No watch job to stop.")
        endif
        call s:changeXTermTitle(s:generateXTermTitle(a:mode, ''))
        call s:clearExUnitWatchCommandCache()
        return
    endif

    let mixDir = vimelixirexunit#findMixDirectory()
    let mixCmd = s:MAKEPRG_MIX_RUN . ' --color --listen-on-stdin'

    let is_xterm_started = vimelixirexunit#findXTerm()
    if !is_xterm_started
        " we will later find `cat`'s pid and stdio by this string
        let terminal_cmd = 'cat - all_cats_are_gray_in_vim_exunit'
        let title = shellescape(s:generateXTermTitle(a:mode, mixDir))

        let xterm_prg = s:wrapIntoTerminalInvocation(terminal_cmd, title)

        let xtermDef = {
            \ 'makeprg': xterm_prg,
            \ 'target': 'ignore',
            \ 'errorformat': ''
            \ }

        call s:runCompiler(xtermDef)
    endif

    if a:mode == 'run_again'
        if s:runExUnitWatchCommandCache != ''
            let makeprg = s:runExUnitWatchCommandCache
        else
            call s:echoDull("No previous command to run tests.")
            return
        endif
    else
        let makeprg = s:getMakeprg(a:mode, mixDir, mixCmd)
    endif

    let is_running = type(s:MIX_TEST_JOB) == 8 && job_status(s:MIX_TEST_JOB) == 'run'
    if !is_running
        call s:clearExUnitWatchCommandCache()
    endif

    if makeprg == s:runExUnitWatchCommandCache
        " send \n to channel(mix test --listen-on-stdin input) to rerun task
        call vimelixirexunit#parseJobOutput('reset', 0)
        call s:sendToJob(s:MIX_TEST_JOB, "\n")
    else
        " run make test in background, control it with sending \n when we
        " want to re-run test, attacht to output
        "
        " send copy of output to xterm so user can see it

        let mix_test_options = {
                    \ 'makeprg': makeprg,
                    \ 'cwd': mixDir,
                    \ 'out_cb': function('vimelixirexunit#processJobOutput'),
                    \ 'postprocess': function('s:exUnitOutputPostprocess'),
                    \ 'errorformat': s:ERROR_FORMATS['exunit_run']
                    \ }

        if is_running
            call s:stopJob(s:MIX_TEST_JOB)
            let s:MIX_TEST_JOB = s:WATCHING_INACTIVE
        endif
        call vimelixirexunit#parseJobOutput('reset', 0)
        let s:MIX_TEST_JOB = s:runJob(mix_test_options)
        let s:runExUnitWatchCommandCache = makeprg
        let s:runExUnitWatchProjectDir = mixDir

        " TODO: find what ESC sequence should be sent to XTerm to change title
        " to new file/mode
        "
        call s:changeXTermTitle(s:generateXTermTitle(a:mode, mixDir))
    endif
endfunction " }}}

function! vimelixirexunit#runExUnitWatchAutoRun() " {{{
    " we have to run it on all file types save ;((((
    if &ft !~ 'elixir' | return | en
    if !g:vim_elixir_exunit_rerun_on_save | return | en
    if !g:vim_elixir_exunit_async | return | en

    let mixDir = vimelixirexunit#findMixDirectory()

    " if there is cached command and we are in same project directory as
    " original test file
    if s:runExUnitWatchCommandCache != '' && mixDir == s:runExUnitWatchProjectDir
        call vimelixirexunit#runExUnitWatchCommand('run_again')
    endif
endfunction " }}}

function! vimelixirexunit#processJobOutput(options, msg) "{{{
    " copy messages from mix test to terminal and also to feed to sign
    " generator
    call vimelixirexunit#postToXTerm(a:options, a:msg)
    call vimelixirexunit#parseJobOutput(a:options, a:msg)
endfunction "}}}

function! vimelixirexunit#parseJobOutput(options, msg) "{{{
    if type(a:options) == 1 && a:options == 'reset'
        cexpr []
    else
        " messages come in batches, so add them to QF buffer, not override
        let options = deepcopy(a:options)
        let options['target'] = 'qfadd'

        let msg = substitute(a:msg, '\[[0-9a-z]\{-1,}m', '', 'g')

        " there is change that postprocess will be confused in messages come
        " in chunks :((( because of forward and backtracing it does
        let errors = s:parseErrorLines(options, msg)
        call s:echoPassFailMessages(errors, 1)
    endif
endfunction "}}}

function! vimelixirexunit#postToXTerm(options, msg) "{{{
    if vimelixirexunit#findXTerm()
        " hacking into Linux /proc filesystem
        " will need similar hacks to another OSes
        let xtermStdin = s:pidToIOFileName(s:XTERM_CAT_PID)
        call s:appendToFile(a:msg, xtermStdin)
    endif
endfunction "}}}

function! vimelixirexunit#findXTerm() " {{{
    if s:XTERM_CAT_PID < 0
        let xterm_text = s:system("ps ax | grep '[0-9] cat - all_cats_are_gray_in_vim_exunit'")
        let xterm_msg = split(xterm_text, " ")

        if len(xterm_msg) > 2
            let s:XTERM_CAT_PID = xterm_msg[0]
        endif
    else
        " check if we still can write to xterm std(in/out)
        " if no - report it, so that it will be restarted
        let fName = s:pidToIOFileName(s:XTERM_CAT_PID)
        if !filewritable(fName)
            let s:XTERM_CAT_PID = -1
        endif
    endif

    return s:XTERM_CAT_PID > 0
endfunction " }}}

function! s:pidToIOFileName(pid) "{{{
    return "/proc/" . a:pid . "/fd/1"
endfunction "}}}

function! s:appendToFile(message, file) "{{{
  silent! new
  silent! setlocal buftype=nofile bufhidden=hide noswapfile nobuflisted
  silent! put=a:message
  silent! normal ggdd
  silent! execute 'w >>' a:file
  silent! q
endfunction "}}}

function! s:changeXTermTitle(title) " {{{
    let args  = g:vimide_terminal_title_change
    let args  = substitute(args, '%TITLE%', a:title, '')
    call vimelixirexunit#postToXTerm({}, args)
endfunction " }}}

function! s:generateXTermTitle(mode, mixDir) " {{{
    " TODO: may be extract and create common part with s:getMakeprg
    let msg = 'ExUnit '
    let fName = expand("%:f")
    if a:mode == 'all'
        let msg .= ' all test '
    elseif a:mode == 'file'
        let msg .= ' ' . fName
    elseif a:mode == 'line'
        let msg .= ' ' . fName .':'. line('.')
    elseif a:mode == 'stop'
        let msg .= ' INACTIVE'
    end

    return msg
endfunction " }}}

function! s:wrapIntoTerminalInvocation(cmd, title) " {{{
    let args  = g:vimide_terminal_run_args
    let args  = substitute(args, '%CMD%', shellescape(a:cmd), '')
    let args  = substitute(args, '%TITLE%', a:title, '')
    let makeprg = g:vimide_terminal . ' ' . args . '&'
    return makeprg
endfunction " }}}

function! s:clearExUnitWatchCommandCache() "{{{
    let s:runExUnitWatchCommandCache = ''
    let s:runExUnitWatchProjectDir = ''
endfunction "}}}

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
    " shortcut ignore case
    if a:options['target'] == 'ignore'
        return []
    endif

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
    endif

    if has_key(a:options, 'leave_valid')
        call filter(errors, "v:val['valid']")
    endif

    let &errorformat = old_errorformat
    let &l:errorformat = old_local_errorformat

    return errors
endfunction " }}}

function! s:runJob(options) "{{{
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
                \ 'out_cb' : {ch, msg -> s:runJobCallback(options, ch, msg)},
                \ 'err_cb' : {ch, msg -> s:runJobCallback(options, ch, msg)},
                \ })

                " \ 'close_cb' : {ch -> echo("channel close ". ch)}

    if has_key(options, 'cwd')
        execute 'lcd ' . fnameescape(old_cwd)
    endif

    return job_id
endfunction "}}}

function! s:stopJob(job_id) "{{{
    " 8 is job type
    if type(a:job_id) == 8
        call job_stop(a:job_id, "term")
        "call job_stop(a:job_id, "int")
    endif
endfunction "}}}

function! s:stopJobOnExit() "{{{
    " correctly cleanup 'mix test' job
    " it requires two SIGINT to clean child processes and does not like
    " SIGTERM
    call s:stopJob(s:MIX_TEST_JOB)
endfunction "}}}

function! s:runJobCallback(options, ch, msg) "{{{
    if has_key(a:options, 'out_cb')
        call a:options['out_cb'](a:options, a:msg)
    endif
endfunction "}}}

function! s:sendToJob(job_id, msg) "{{{
    let ch = job_getchannel(a:job_id)
    call ch_sendraw(ch, a:msg)
endfunction "}}}

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

    " only for tests
    let s:dump_error_content=error_content

    let errors = s:parseErrorLines(options, error_content)

    call s:revertQFLocationWindow(options)

    return errors
endfunction " }}}

function s:revertQFLocationWindow(options) "{{{
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
endfunction "}}}

let s:navigateQuickFixCachedLine=-1
function! s:navigateQuickFix(direction) "{{{
    try
        if a:direction == 'next'
            cnext
        elseif a:direction == 'prev'
            cprevious
        else
            return
        endif
    catch
        try
            cc
        catch
            call s:echoWarning("No errors available, please write more code with errors.")
        endtry
        "return
    endtry

    if foldlevel('.') > 0 && foldclosed('.') >= 0
        . foldopen
    endif

    normal zz

    let currentBuffer = bufnr('%')
    let line = line('.')

    let thisLineMsg = filter(getqflist(), "v:val['valid'] == 1 && v:val['lnum'] == " . line . " && v:val['bufnr'] == " . currentBuffer)

    if len(thisLineMsg) == 0 | return | en

    let msgIndex = 0

    if line == s:navigateQuickFixCachedLine && len(thisLineMsg) > 1
        " TODO: later make it possible to have more than 2 msg on single line
        " this will require some caching on seen line No and counter which msg
        " we show right now
        let msgIndex = (a:direction == "next" ? 1 : 0)
    endif

    let msg = thisLineMsg[msgIndex]['text']
    let lnNum = line('.')
    let ln = getline(lnNum)
    let column = -1

    if msg =~ '^variable "\?\S\+"\? '
        let msgSplit = split(msg)
        let varName = substitute(msgSplit[1], '"', '', 'g')
        let varname = '\<' . varName . '\>'

        let position = -1
        let matches = matchstrpos(ln, varname)
        let origMatches = matches

        while matches[0] != ''
            let synItem = synIDattr(synID(lnNum, matches[1]+1, 1),"name")
            "echom join(matches)
            "echom synItem

            if (synItem == 'elixirId' || synItem == 'elixirArguments')
                let column = matches[1]
                break
            endif
            let matches = matchstrpos(ln, varname, matches[2])
        endwhile

        if matches[0] == ''
            let column = origMatches[1]
        endif
    endif

    if column != -1
        call cursor(lnNum, column+1)
        normal zz
    endif

    let s:navigateQuickFixCachedLine = line
endfunction "}}}

function! s:echoWarning(text) "{{{
    echohl WarningMsg | echo a:text | echohl None
endfunction "}}}

function! s:echoNormal(text) "{{{
    echohl Normal | echo a:text | echohl None
endfunction "}}}

function! s:echoInfoText(text) "{{{
    echohl Question | echo a:text | echohl None
endfunction "}}}

function! s:echoDull(text) "{{{
    echohl Normal | echo a:text | echohl None
endfunction "}}}

function! s:setGlobal(name, default) " {{{
  if !exists(a:name)
    if type(a:name) == 0 || type(a:name) == 5
      exec "let " . a:name . " = " . a:default
    elseif type(a:name) == 1
      exec "let " . a:name . " = '" . escape(a:default, "\'") . "'"
    endif
  endif
endfunction " }}}

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

" solely for debug"{{{
let s:dump_error_content=''
function! vimelixirexunit#testShowContent()
    echo s:dump_error_content
endfunction "}}}

function! vimelixirexunit#testParseErrorLines(formatType, content, valid) "{{{
    " utility API just to allow rspec access internal formats
    let options = {
                \ "errorformat": s:ERROR_FORMATS[a:formatType],
                \ 'target': "llist"
                \ }

    let options['leave_valid'] = (a:valid =~ 'v')
    if a:valid !~ 'r'
        " do not want raw output
        let options['postprocess'] = function('s:exUnitOutputPostprocess')
    endif

    return s:parseErrorLines(options, a:content)
endfunction "}}}

augroup ElixirExUnit " {{{
    au!
    au VimLeave call s:stopJobOnExit()
    " for now use simple logic to detect files without need to check ALL
    " extensions saves
    au BufWritePost *.ex,*.exs call vimelixirexunit#runExUnitWatchAutoRun()
augroup END " }}}

" vim: set sw=4 sts=4 et fdm=marker:
"
