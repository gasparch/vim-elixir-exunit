# frozen_string_literal: true

require 'rspec/expectations'
require 'tmpdir'
require 'vimrunner'
require 'vimrunner/rspec'
require 'pry'

class Buffer
  def initialize(vim, type)
    @mix_file = "mix.exs"
    @test_helper = "test/test_helper.exs"

    write_mix_exs

    if type == :test_exs
      Dir.mkdir("test")
      write_test_helper
      type = :exs
      @file = "test/fixture_test.#{type}"
    else
      Dir.mkdir("lib")
      @file = "lib/fixture.#{type}"
    end

    @vim = vim
  end

  def get_parsed_errors(content, error_type, leave=1)
    result = @vim.command "echo vimelixirexunit#testParseErrorLines('#{error_type}', #{content.dump}, #{leave})"
    result.gsub(/ 'bufnr': \d+,/, '').gsub(/ 'pattern': '',/, '')
  end

  def get_quickfix_output(content, command)
    result = ''
    with_file content do
      @vim.command command
      @vim.command "copen"
      result = @vim.command 'echo join(getline(0, "$"), "\\n")'
      result = result.gsub(/\s*$/, '')

      if false
        locresult = @vim.command ":call ShowContent()"
        @vim.command ":qa!"
        print "---- raw output -\n"
        print locresult
        print "\n-- parsed err ---\n"
        print result
        print "\n--------------------------------\n"
        #exit!(123)
      end

      result
    end
    result
  end

  def messages_clear
    @vim.command ':messages clear'
  end

  def messages
    @vim.command ':messages'
  end

  private

  def write_mix_exs
    content=<<~EOF
defmodule OddsFeed.Mixfile do
  use Mix.Project
  def project do
    [app: :test,
     version: "0.1.0",
     elixir: "~> 1.3",
     deps: [],
     aliases: []
   ]
  end
end

    EOF
    File.write(@mix_file, content)
  end

  def write_test_helper
    content=<<~EOF
ExUnit.start()
    EOF
    File.write(@test_helper, content)
  end

  def with_file(content = nil)
    edit_file(content)

    yield if block_given?

    @vim.write
    IO.read(@file)
  end

  def edit_file(content)
    File.write(@file, content) if content

    @vim.edit @file
    @vim.normal ':set ft=elixir<CR>'
  end

end

class Differ
  def self.diff(result, expected)
    instance.diff(result, expected)
  end

  def self.instance
    @instance ||= new
  end

  def initialize
    @differ = RSpec::Support::Differ.new(
      object_preparer: -> (object) do
        RSpec::Matchers::Composable.surface_descriptions_in(object)
      end,
      color: RSpec::Matchers.configuration.color?
    )
  end

  def diff(result, expected)
    @differ.diff_as_object(result, expected)
  end
end


RSpec::Matchers.define :be_matching_error do |error_type, expected_result|
  buffer = Buffer.new(VIM, :ex)

  expected_result = expected_result.gsub(/\n$/, '')

  match do |code|
    buffer.get_parsed_errors(code, error_type) == expected_result
  end

  failure_message do |code|
    buffer.messages_clear
    result = buffer.get_parsed_errors(code, error_type)
    messages = buffer.messages

    <<~EOM
    Vim echo messages:
    #{messages}

    Diff:
    #{Differ.diff(result, expected_result)}
    EOM
  end
end

RSpec::Matchers.define :be_quickfix_content do |command, expected_result|
  buffer = Buffer.new(VIM, :ex)

  if command == 'make'
    run_command = ":make"
  elsif command == "MixCompile"
    run_command = ":MixCompile"
  end

  expand_result = expected_result.gsub(/%%DIRNAME%%/, Dir.pwd).gsub(/\n$/, '')

  match_result = ''

  match do |code|
    match_result = buffer.get_quickfix_output(code, run_command)
    match_result == expand_result
  end

  failure_message do |code|
    #buffer.messages_clear
    #result = buffer.get_quickfix_output(code, run_command)
    messages = buffer.messages

    result = match_result

    <<~EOM
    Vim echo messages:
    #{messages}

    Diff:
    #{Differ.diff(result, expand_result)}
    EOM
  end
end

RSpec::Matchers.define :be_test_output do |command, expected_result|
  buffer = Buffer.new(VIM, :test_exs)

  if command == 'ExUnitRunAll'
    run_command = ":ExUnitRunAll"
  elsif command == "MixCompile11123"
    run_command = ":MixCompile123123"
  end

  expand_result = expected_result.gsub(/%%DIRNAME%%/, Dir.pwd).gsub(/\n$/, '')

  match_result = ''

  match do |code|
    match_result = buffer.get_quickfix_output(code, run_command)
    match_result = match_result.gsub(/<\d+\.\d+\.\d+(\.\d+)?>/, '')

    lines = match_result.
      split(/\n/).
      find_all {|x| x !~ /Finished in/ && x !~ /Randomized/}

    match_result = lines.join("\n")
    match_result == expand_result
  end

  failure_message do |code|
    #buffer.messages_clear
    #result = buffer.get_quickfix_output(code, run_command)
    messages = buffer.messages

    result = match_result

    <<~EOM
    Vim echo messages:
    #{messages}

    Diff:
    #{Differ.diff(result, expand_result)}
    EOM
  end
end

Vimrunner::RSpec.configure do |config|
  config.reuse_server = true

  config.start_vim do
    VIM = Vimrunner.start_gvim
    VIM.add_plugin(File.expand_path('..', __dir__), 'autoload/vimelixirexunit.vim')
    VIM.add_plugin(File.expand_path('..', __dir__), 'ftplugin/elixir.vim')
    VIM
  end
end

RSpec.configure do |config|
  config.order = :random

  # Run a single spec by adding the `focus: true` option
  config.filter_run_including focus: true
  config.run_all_when_everything_filtered = true
end
