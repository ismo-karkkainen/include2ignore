# frozen_string_literal: true

# Initial tests via OpenCode/Ollama/GLM-4.7-flash. Minor fixes by human.

require 'test/unit'
require 'stringio'
require 'singleton'
require_relative '../lib/include2ignore/warnings'

class TestInclude2IgnoreWarnings < Test::Unit::TestCase
  def setup
    @warnings = Include2Ignore::Warnings.instance
    @output_buffer = StringIO.new
    Include2Ignore::Warnings.output(@output_buffer)
    @warnings.instance_variable_set(:@verbose, false)
    @warnings.send(:remove_instance_variable, :@context) if @warnings.respond_to?(:@context)
    Include2Ignore::Warnings.instance_variable_set(:@context, nil)
  end

  def teardown
    Include2Ignore::Warnings.instance_variable_set(:@context, nil)
  end

  def test_where_set_context
    @warnings.where('test_location')
    assert_equal('test_location', @warnings.context)
  end

  def test_where_class_method
    Include2Ignore::Warnings.where('class_location')
    assert_equal('class_location', Include2Ignore::Warnings.instance.context)
  end

  def test_warn_with_context
    @warnings.where('test_location')
    @warnings.warn('test message')

    output = @output_buffer.string
    assert_equal('test_location', output.lines[0].rstrip)
    assert_equal('  test message', output.lines[1].rstrip)
  end

  def test_warn_without_context
    @warnings.warn('test message')
    output = @output_buffer.string
    assert_equal('  test message', output.rstrip)
  end

  def test_warn_clears_context
    @warnings.where('test_location')
    @warnings.warn('test message')

    assert_nil(@warnings.context)
  end

  def test_warn_class_method
    @warnings.where('test_location')
    Include2Ignore::Warnings.warn('class method message')

    output = @output_buffer.string
    assert_equal('test_location', output.lines[0].rstrip)
    assert_equal('  class method message', output.lines[1].rstrip)
  end

  def test_output_explanations_sets_verbose
    Include2Ignore::Warnings.output_explanations(true)
    assert_true(Include2Ignore::Warnings.instance.verbose)

    Include2Ignore::Warnings.output_explanations(false)
    assert_false(Include2Ignore::Warnings.instance.verbose)
  end

  def test_explain_false_when_not_verbose
    @warnings.where('test_location')
    @warnings.instance_variable_set(:@verbose, false)
    @warnings.explain('explanation message')

    assert_equal('', @output_buffer.string)
  end

  def test_explain_when_verbose
    @warnings.where('test_location')
    @warnings.instance_variable_set(:@verbose, true)
    @warnings.explain('explanation message')

    output = @output_buffer.string
    assert_equal('test_location', output.lines[0].rstrip)
    assert_equal('  explanation message', output.lines[1].rstrip)
  end

  def test_explain_class_method
    @warnings.where('test_location')
    @warnings.instance_variable_set(:@verbose, true)
    Include2Ignore::Warnings.explain('class explanation')

    output = @output_buffer.string
    assert_equal('test_location', output.lines[0].rstrip)
    assert_equal('  class explanation', output.lines[1].rstrip)
  end

  def test_explain_false_verbose_class_method
    @warnings.where('test_location')
    Include2Ignore::Warnings.explain('class explanation')

    assert_equal('', @output_buffer.string)
  end

  def test_complete_workflow
    Include2Ignore::Warnings.output_explanations(true)
    Include2Ignore::Warnings.where('source:file.rb')
    Include2Ignore::Warnings.warn('Unused import')
    Include2Ignore::Warnings.explain('This import is never used')
    Include2Ignore::Warnings.explain('Consider removing it')

    output = @output_buffer.string
    assert_equal('source:file.rb', output.lines[0].rstrip)
    assert_equal('  Unused import', output.lines[1].rstrip)
    assert_equal('  This import is never used', output.lines[2].rstrip)
    assert_equal('  Consider removing it', output.lines[3].rstrip)
  end
end
