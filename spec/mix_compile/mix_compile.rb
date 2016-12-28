# frozen_string_literal: true

require 'spec_helper'

describe 'parsing compiler errors' do
  it "undefined identificator/function" do
    content = "[{'lnum': 13, 'col': 0, 'valid': 1, 'vcol': 0, 'nr': -1, 'type': 'E', 'text': 'undefined function start/1'}]"

    expect(<<~EOF).to be_matching_error("mix_compile", content)
== Compilation error on file lib/feed_app.ex ==
** (CompileError) lib/feed_app.ex:13: undefined function start/1
    (stdlib) lists.erl:1338: :lists.foreach/2
    (elixir) lib/kernel/parallel_compiler.ex:117: anonymous fn/4 in Kernel.ParallelCompiler.spa
    EOF
  end

  it "unclosed do/end" do
    content = "[{'lnum': 60, 'col': 0, 'valid': 1, 'vcol': 0, 'nr': -1, 'type': 'E', 'text': 'missing terminator: end (for \"do\" starting at line 3)'}]"

    expect(<<~EOF).to be_matching_error("mix_compile", content)
== Compilation error on file lib/odds_feed_app.ex ==
** (TokenMissingError) lib/odds_feed_app.ex:60: missing terminator: end (for "do" starting at line 3)
    (elixir) lib/kernel/parallel_compiler.ex:117: anonymous fn/4 in Kernel.ParallelCompiler.spawn_compilers/1
    EOF
  end
end

describe 'parsing compiler warnings' do
  it "warning msg" do
    content = "[" +
      "{'lnum': 94, 'col': 0, 'valid': 1, 'vcol': 0, 'nr': -1, 'type': 'W', 'text': 'variable level is unused'}, " +
      "{'lnum': 94, 'col': 0, 'valid': 1, 'vcol': 0, 'nr': -1, 'type': 'W', 'text': 'the result of the expression is ignored (suppress the warning by assigning the expression to the _ variable)'}, " +
      "{'lnum': 7, 'col': 0, 'valid': 1, 'vcol': 0, 'nr': -1, 'type': 'W', 'text': 'unused alias Levels'}" +
      "]"

    expect(<<~EOF).to be_matching_error("mix_compile", content, 'vr')
Compiling 7 files (.ex)
warning: variable level is unused
  lib/foo/bar/baz.ex:94

warning: the result of the expression is ignored (suppress the warning by assigning the expression to the _ variable)
  lib/foo/bar/baz.ex:94

warning: unused alias Levels
  lib/foo/bar/baz.ex:7
    EOF
  end
end

describe 'running make' do
  it "error msg is reported" do
    content = <<~EOF
|| **CWD**%%DIRNAME%%
|| Compiling 1 file (.ex)
lib/fixture.ex|3 error| undefined function asd/0
EOF

    expect(<<~EOF).to be_quickfix_content("make", content)
defmodule A do
  def test() do
    asd()
  end
end
    EOF
  end

  it "warning msg is not reported" do
    content = <<~EOF
|| **CWD**%%DIRNAME%%
|| Compiling 1 file (.ex)
|| Generated test app
EOF

    expect(<<~EOF).to be_quickfix_content("make", content)
defmodule A do
  def test() do
    foo = 123
  end
end
    EOF
  end
end

describe 'running MixCompile command' do
  it "error msg is reported" do
    content = <<~EOF
|| **CWD**%%DIRNAME%%
|| Compiling 1 file (.ex)
lib/fixture.ex|3 error| undefined function asd/0
EOF

    expect(<<~EOF).to be_quickfix_content("MixCompile", content)
defmodule A do
  def test() do
    asd()
  end
end
    EOF
  end

  it "warning msg is reported" do
    content = <<~EOF
|| **CWD**%%DIRNAME%%
|| Compiling 1 file (.ex)
lib/fixture.ex|3 warning| variable foo is unused
|| Generated test app
EOF

    expect(<<~EOF).to be_quickfix_content("MixCompile", content)
defmodule A do
  def test() do
    foo = 123
  end
end
    EOF
  end
end
