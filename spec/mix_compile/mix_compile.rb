# frozen_string_literal: true

require 'spec_helper'

describe 'parsing compiler errors' do
  it "undefined identificator/function" do
    content = "[{'lnum': 13, 'bufnr': 2, 'col': 0, 'valid': 1, 'vcol': 0, 'nr': -1, 'type': 'E', 'pattern': '', 'text': 'undefined function start/1'}]"

    expect(<<~EOF).to be_matching_error("mix_compile", content)
== Compilation error on file lib/feed_app.ex ==
** (CompileError) lib/feed_app.ex:13: undefined function start/1
    (stdlib) lists.erl:1338: :lists.foreach/2
    (elixir) lib/kernel/parallel_compiler.ex:117: anonymous fn/4 in Kernel.ParallelCompiler.spa
    EOF
  end
end
