# frozen_string_literal: true

require 'spec_helper'

describe 'running ExUnitRunAll command' do
  it "passing test" do # {{{
    content = <<~EOF
|| **CWD**%%DIRNAME%%
|| .
|| 1 test, 0 failures
EOF

    expect(<<~EOF).to be_test_output("ExUnitRunAll", content)
defmodule A do
  use ExUnit.Case
  test "truth" do
    assert 1 == 1
  end
end
    EOF
  end # }}}

  it "compilation error(undefined function)" do # {{{
    content = <<~EOF
|| **CWD**%%DIRNAME%%
test/fixture_test.exs|4 error| undefined function call/0
EOF

    expect(<<~EOF).to be_test_output("ExUnitRunAll", content)
defmodule A do
  use ExUnit.Case
  test "truth" do
    call()
  end
end
    EOF
  end # }}}

  it "compilation error(missing do)" do # {{{
    content = <<~EOF
|| **CWD**%%DIRNAME%%
test/fixture_test.exs|6 error| unexpected token: end
EOF

    expect(<<~EOF).to be_test_output("ExUnitRunAll", content)
defmodule A do
  use ExUnit.Case
  test "truth" 
    :ok
  end
end
    EOF
  end # }}}

  it "compilation error(missing end)" do # {{{
    content = <<~EOF
|| **CWD**%%DIRNAME%%
test/fixture_test.exs|8 error| missing terminator: end (for "do" starting at line 1)
EOF

    expect(<<~EOF).to be_test_output("ExUnitRunAll", content)
defmodule A do
  use ExUnit.Case
  test "truth" do
    if true do
      :ok
  end
end
    EOF
  end # }}}

  it "failing assert" do # {{{
    content = <<~EOF
|| **CWD**%%DIRNAME%%
test/fixture_test.exs|3 error| test truth (A)
||      Assertion with == failed
||      code: 2 == 1
||      lhs:  2
||      rhs:  1
test/fixture_test.exs|4 error| (test)
|| 1 test, 1 failure
EOF

    source = <<~EOF
defmodule A do
  use ExUnit.Case
  test "truth" do
    assert 2 == 1
  end
end
    EOF

    expect(source).to be_test_output("ExUnitRunAll", content)

    mix_test_output = <<~EOF
Generated test app


  1) test truth (A)
     test/fixture_test.exs:3
     Assertion with == failed
     code: 2 == 1
     lhs:  2
     rhs:  1
     stacktrace:
       test/fixture_test.exs:4: (test)



Finished in 0.06 seconds
1 test, 1 failure

Randomized with seed 948545
    EOF

    internal_content = <<~EOF
[{'lnum': 3, 'col': 0, 'valid': 1, 'vcol': 0, 'nr': -1, 'type': 'E', 'text': 'test truth (A)'}, {'lnum': 4, 'col': 0, 'valid': 1, 'vcol': 0, 'nr': -1, 'type': 'E', 'text': '(test)'}]
    EOF

    expect(mix_test_output).to be_matching_error("exunit_run", internal_content)
  end # }}}

  it "failing function call" do # {{{
    content = <<~EOF
|| **CWD**%%DIRNAME%%
test/fixture_test.exs|3 error| test truth (A)
test/fixture_test.exs|8 error| A.test_me/1 ** (MatchError) no match of right hand side value: 123
test/fixture_test.exs|4 error| (test)
|| 1 test, 1 failure
EOF

    expect(<<~EOF).to be_test_output("ExUnitRunAll", content)
defmodule A do
  use ExUnit.Case
  test "truth" do
    test_me 123
  end

  defp test_me(arg) do
    {_, _} = arg
  end
end
    EOF

    mix_test_output = <<~EOF
Generated test app


  1) test truth (A)
     test/fixture_test.exs:3
     ** (MatchError) no match of right hand side value: 123
     stacktrace:
       test/fixture_test.exs:8: A.test_me/1
       test/fixture_test.exs:4: (test)



Finished in 0.1 seconds
1 test, 1 failure

Randomized with seed 78859
    EOF

    internal_content = <<~EOF
[{'lnum': 3, 'col': 0, 'valid': 1, 'vcol': 0, 'nr': -1, 'type': 'E', 'text': 'test truth (A)'}, {'lnum': 8, 'col': 0, 'valid': 1, 'vcol': 0, 'nr': -1, 'type': 'E', 'text': 'A.test_me/1 ** (MatchError) no match of right hand side value: 123'}, {'lnum': 4, 'col': 0, 'valid': 1, 'vcol': 0, 'nr': -1, 'type': 'E', 'text': '(test)'}]
    EOF

    expect(mix_test_output).to be_matching_error("exunit_run", internal_content)
  end # }}}

  it "absent function call" do # {{{
    content = <<~EOF
|| **CWD**%%DIRNAME%%
test/fixture_test.exs|3 error| test truth (A)
||        A.test_other(123)
test/fixture_test.exs|4 error| (test) ** (UndefinedFunctionError) function A.test_other/1 is undefined or private
|| 1 test, 1 failure
EOF

    expect(<<~EOF).to be_test_output("ExUnitRunAll", content)
defmodule A do
  use ExUnit.Case
  test "truth" do
    A.test_other 123
  end
end
    EOF

    mix_test_output = <<~EOF
Generated test app


  1) test truth (A)
     test/fixture_test.exs:3
     ** (UndefinedFunctionError) function A.test_other/1 is undefined or private
     stacktrace:
       A.test_other(123)
       test/fixture_test.exs:4: (test)



Finished in 0.06 seconds
1 test, 1 failure

Randomized with seed 768998
    EOF

    internal_content = <<~EOF
[{'lnum': 3, 'col': 0, 'valid': 1, 'vcol': 0, 'nr': -1, 'type': 'E', 'text': 'test truth (A)'}, {'lnum': 4, 'col': 0, 'valid': 1, 'vcol': 0, 'nr': -1, 'type': 'E', 'text': '(test) ** (UndefinedFunctionError) function A.test_other/1 is undefined or private'}]
    EOF

    expect(mix_test_output).to be_matching_error("exunit_run", internal_content)

  end # }}}

  it "ignore warnings" do # {{{
    content = <<~EOF
|| **CWD**%%DIRNAME%%
test/fixture_test.exs|3 error| test truth (A)
||        A.test_other(123)
test/fixture_test.exs|4 error| (test) ** (UndefinedFunctionError) function A.test_other/1 is undefined or private
|| 1 test, 1 failure
EOF

    expect(<<~EOF).to be_test_output("ExUnitRunAll", content)
defmodule A do
  use ExUnit.Case
  test "truth" do
    A.test_other 123
  end

  defp test_warning do
    :ok
  end
end
    EOF

    mix_test_output = <<~EOF
Generated test app
warning: function test_warning/0 is unused
  test/fixture_test.exs:7



  1) test truth (A)
     test/fixture_test.exs:3
     ** (UndefinedFunctionError) function A.test_other/1 is undefined or private
     stacktrace:
       A.test_other(123)
       test/fixture_test.exs:4: (test)



Finished in 0.09 seconds
1 test, 1 failure

Randomized with seed 397976
    EOF

    internal_content = <<~EOF
[{'lnum': 3, 'col': 0, 'valid': 1, 'vcol': 0, 'nr': -1, 'type': 'E', 'text': 'test truth (A)'}, {'lnum': 4, 'col': 0, 'valid': 1, 'vcol': 0, 'nr': -1, 'type': 'E', 'text': '(test) ** (UndefinedFunctionError) function A.test_other/1 is undefined or private'}]
    EOF

    expect(mix_test_output).to be_matching_error("exunit_run", internal_content)

  end # }}}

  it "parse GenServer clause undefined" do # {{{
    content = <<~EOF
|| **CWD**%%DIRNAME%%
test/fixture_test.exs|3 error| test truth (A)
test/fixture_test.exs|21 error| B.handle_call(:nonexistent, {#PID, #Reference}, :state) ** (FunctionClauseError) no function clause matching in B.handle_call/3
|| 1 test, 1 failure
EOF

    expect(<<~EOF).to be_test_output("ExUnitRunAll", content)
defmodule A do
  use ExUnit.Case
  test "truth" do
    {:ok, pid} = B.start_link()
    GenServer.call(pid, :nonexistent)
    :ok
  end
end

defmodule B do
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, [], [])
  end

  def init(_) do
    {:ok, :state}
  end

  def handle_call(:never_called, _, state) do
    {:reply, :ok, state}
  end
end
    EOF

    mix_test_output = <<~EOF
Generated test app

=ERROR REPORT==== 27-Dec-2016::01:01:48 ===
** Generic server <0.130.0> terminating 
** Last message in was nonexistent
** When Server state == state
** Reason for termination == 
** {function_clause,[{'Elixir.B',handle_call,
                                 [nonexistent,
                                  {<0.129.0>,#Ref<0.0.1.27>},
                                  state],
                                 [{file,"test/fixture_test.exs"},{line,21}]},
                     {gen_server,try_handle_call,4,
                                 [{file,"gen_server.erl"},{line,615}]},
                     {gen_server,handle_msg,5,
                                 [{file,"gen_server.erl"},{line,647}]},
                     {proc_lib,init_p_do_apply,3,
                               [{file,"proc_lib.erl"},{line,247}]}]}


  1) test truth (A)
     test/fixture_test.exs:3
     ** (EXIT from #PID<0.129.0>) an exception was raised:
         ** (FunctionClauseError) no function clause matching in B.handle_call/3
             test/fixture_test.exs:21: B.handle_call(:nonexistent, {#PID<0.129.0>, #Reference<0.0.1.27>}, :state)
             (stdlib) gen_server.erl:615: :gen_server.try_handle_call/4
             (stdlib) gen_server.erl:647: :gen_server.handle_msg/5
             (stdlib) proc_lib.erl:247: :proc_lib.init_p_do_apply/3



Finished in 0.1 seconds
1 test, 1 failure

Randomized with seed 442759
    EOF

    internal_content = <<~EOF
[{'lnum': 3, 'col': 0, 'valid': 1, 'vcol': 0, 'nr': -1, 'type': 'E', 'text': 'test truth (A)'}, {'lnum': 21, 'col': 0, 'valid': 1, 'vcol': 0, 'nr': -1, 'type': 'E', 'text': 'B.handle_call(:nonexistent, {#PID<0.129.0>, #Reference<0.0.1.27>}, :state) ** (FunctionClauseError) no function clause matching in B.handle_call/3'}]
    EOF

    expect(mix_test_output).to be_matching_error("exunit_run", internal_content)

  end # }}}

  it "parse crash inside GenServer clause" do # {{{
    content = <<~EOF
|| **CWD**%%DIRNAME%%
test/fixture_test.exs|3 error| test truth (A)
test/fixture_test.exs|22 error| B.handle_call/3 ** (MatchError) no match of right hand side value: :state
|| 1 test, 1 failure
    EOF

    expect(<<~EOF).to be_test_output("ExUnitRunAll", content)
defmodule A do
  use ExUnit.Case
  test "truth" do
    {:ok, pid} = B.start_link()
    GenServer.call(pid, :crashes)
    :ok
  end
end

defmodule B do
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, [], [])
  end

  def init(_) do
    {:ok, :state}
  end

  def handle_call(:crashes, _, state) do
    {_, _} = state
    {:reply, :ok, state}
  end
end
    EOF

    mix_test_output = <<~EOF
Generated test app

=ERROR REPORT==== 27-Dec-2016::01:22:41 ===
** Generic server <0.130.0> terminating 
** Last message in was crashes
** When Server state == state
** Reason for termination == 
** {{badmatch,state},
    [{'Elixir.B',handle_call,3,[{file,"test/fixture_test.exs"},{line,22}]},
     {gen_server,try_handle_call,4,[{file,"gen_server.erl"},{line,615}]},
     {gen_server,handle_msg,5,[{file,"gen_server.erl"},{line,647}]},
     {proc_lib,init_p_do_apply,3,[{file,"proc_lib.erl"},{line,247}]}]}


  1) test truth (A)
     test/fixture_test.exs:3
     ** (EXIT from #PID<0.129.0>) an exception was raised:
         ** (MatchError) no match of right hand side value: :state
             test/fixture_test.exs:22: B.handle_call/3
             (stdlib) gen_server.erl:615: :gen_server.try_handle_call/4
             (stdlib) gen_server.erl:647: :gen_server.handle_msg/5
             (stdlib) proc_lib.erl:247: :proc_lib.init_p_do_apply/3



Finished in 0.1 seconds
1 test, 1 failure

Randomized with seed 816037
    EOF

    internal_content = <<~EOF
[{'lnum': 3, 'col': 0, 'valid': 1, 'vcol': 0, 'nr': -1, 'type': 'E', 'text': 'test truth (A)'}, {'lnum': 22, 'col': 0, 'valid': 1, 'vcol': 0, 'nr': -1, 'type': 'E', 'text': 'B.handle_call/3 ** (MatchError) no match of right hand side value: :state'}]
    EOF

    expect(mix_test_output).to be_matching_error("exunit_run", internal_content)
  end # }}}

end


# vim: foldmethod=marker
