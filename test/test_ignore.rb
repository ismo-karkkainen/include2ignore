# frozen_string_literal: true

# Tests by OpenCode/gemma4:26b-nvfp4/Ollama.
# Human edits.

require 'test/unit'
require 'stringio'
require 'tempfile'
require_relative '../lib/include2ignore/ignore'
require_relative '../lib/include2ignore/config'

class TestIgnore < Test::Unit::TestCase
  class MockOutput
    attr_reader :lines
    def initialize
      @lines = []
    end

    def puts(line)
      @lines << "#{line}\n"
    end
  end

  def test_initialize_with_nil
    ignore = Include2Ignore::Ignore.new(nil, Include2Ignore::IgnoreConfiguration::Configuration.new({ 'include' => false, 'ignore' => '' }))
    assert_equal($stdout, ignore.output)
  end

  def test_initialize_with_string
    temp = Tempfile.new('ignore_test')
    begin
      ignore = Include2Ignore::Ignore.new(temp.path, Include2Ignore::IgnoreConfiguration::Configuration.new({ 'include' => false, 'ignore' => '' }))
      if ignore.output.respond_to?(:path)
        assert_equal(temp.path, ignore.output.path)
      end
      ignore.close
    ensure
      temp.close
      temp.unlink
    end
  end

  def test_initialize_with_mock
    mock = MockOutput.new
    ignore = Include2Ignore::Ignore.new(mock, Include2Ignore::IgnoreConfiguration::Configuration.new({ 'include' => '', 'ignore' => '' }))
    assert_equal(mock, ignore.output)

    ignore.add_include('test_line')
    assert_equal(["test_line\n"], mock.lines)
  end

  def test_initialize_with_invalid
    assert_raise(ArgumentError) { Include2Ignore::Ignore.new(1, Include2Ignore::IgnoreConfiguration::Configuration.new({ 'include' => false, 'ignore' => '' })) }
  end

  def test_add_include_omit_exclude
    mock = MockOutput.new
    ignore = Include2Ignore::Ignore.new(mock, Include2Ignore::IgnoreConfiguration::Configuration.new({ 'include' => 'x', 'ignore' => false }))

    ignore.add_include('file.txt')
    assert_equal(["xfile.txt\n"], mock.lines)

    ignore.add_exclude('dir/')
    assert_equal(["xfile.txt\n"], mock.lines)
  end

  def test_omit_include_add_exclude
    mock = MockOutput.new
    ignore = Include2Ignore::Ignore.new(mock, Include2Ignore::IgnoreConfiguration::Configuration.new({ 'include' => false, 'ignore' => 'x' }))

    ignore.add_include('file.txt')
    assert(mock.lines.empty?)

    ignore.add_exclude('dir/')
    assert_equal(["xdir/\n"], mock.lines)
  end
end

class TestLevel < Test::Unit::TestCase
  def test_initialize
    level = Include2Ignore::Level.new(0, ['home'], true)
    assert_equal(0, level.level)
    assert_equal('/home/', level.name)
  end

  def test_decided_name
    assert_equal('/home/user/', Include2Ignore::Level.decided_name(%w[home user], true))
    assert_equal('/home/user', Include2Ignore::Level.decided_name(%w[home user], false))
  end

  def test_add_and_counts
    root = Include2Ignore::Level.new(0, [], true)

    # dir_a (level 0) -> file_a1 (level 1, included)
    root.add(%w[dir_a file_a1], false, false)

    # dir_b (level 0) -> file_b1 (level 1, included), file_b2 (level 1, excluded)
    root.add(%w[dir_b file_b1], false, false)
    root.add(%w[dir_b file_b2], true, false)

    # dir_c (level 0, excluded)
    root.add(['dir_c'], true, true)

    # counts for root:
    # dir_a: 1 inc
    # dir_b: 1 inc, 1 ex
    # dir_c: 1 ex
    # Sum: [2, 0, 2]

    inc, und, ex = root.counts
    assert_equal(2, inc)
    assert_equal(0, und)
    assert_equal(2, ex)
  end

  def test_exclude_undecided
    root = Include2Ignore::Level.new(0, [], true)

    # Add an undecided child at level 1
    undecided_child = Include2Ignore::Level.new(1, ['undecided'], true)
    root.children['undecided'] = undecided_child

    # Verify it is undecided
    assert_nil(undecided_child.kind)

    # Add an included child at level 1
    root.add(%w[dir_a file_a], false, false)

    # counts: [1, 1, 0]
    inc, und, ex = root.counts
    assert_equal(1, inc)
    assert_equal(1, und)
    assert_equal(0, ex)

    root.exclude_undecided
    assert_equal(true, undecided_child.kind)

    inc, und, ex = root.counts
    assert_equal(1, inc)
    assert_equal(0, und)
    assert_equal(1, ex)
  end

  def test_output
    saver = Object.new
    def saver.add_include(name)
      @inc ||= []
      @inc << name
    end

    def saver.add_exclude(name)
      @ex ||= []
      @ex << name
    end

    def saver.include_count
      @inc ? @inc.size : 0
    end

    def saver.exclude_count
      @ex ? @ex.size : 0
    end

    root = Include2Ignore::Level.new(0, [], true)
    root.add(%w[dir_a file_a], false, false)
    root.add(%w[dir_b file_b], true, false)

    root.output(saver)

    assert_equal(1, saver.include_count)
    assert_equal(1, saver.exclude_count)
  end
end

class TestClassified < Test::Unit::TestCase
  def test_add_and_counts
    classified = Include2Ignore::Classified.new

    classified.add(%w[dir_a file_a], false, false)
    classified.add(['dir_b'], true, true)
    classified.add(['undecided'], nil, true)

    # Total: [1, 1, 1]
    inc, und, ex = classified.counts
    assert_equal(1, inc)
    assert_equal(1, und)
    assert_equal(1, ex)
  end

  def test_pick
    classified = Include2Ignore::Classified.new
    classified.add(['dir_u'], nil, true)

    inc, und, ex = classified.counts
    assert_equal(0, inc)
    assert_equal(1, und)
    assert_equal(0, ex)

    classified.pick

    inc, und, ex = classified.counts
    assert_equal(0, inc)
    assert_equal(0, und)
    assert_equal(1, ex)
  end

  def test_output
    saver = Object.new
    def saver.add_include(name)
      @inc ||= []
      @inc << name
    end

    def saver.add_exclude(name)
      @ex ||= []
      @ex << name
    end

    def saver.include_count
      @inc ? @inc.size : 0
    end

    def saver.exclude_count
      @ex ? @ex.size : 0
    end

    classified = Include2Ignore::Classified.new
    classified.add(%w[dir_a file_a], false, false)
    classified.add(['dir_b'], true, true)

    classified.output(saver)

    assert_equal(1, saver.include_count)
    assert_equal(1, saver.exclude_count)
  end
end
