# frozen_string_literal: true

# Tests by OpenCode and via ollama:
# glm-4.7-flash:latest, qwen3.8:27b-mlx, and gemma4:12b-mxfp8.
# Minor edits and additions by a human.

require 'test/unit'
require_relative '../lib/include2ignore/warnings'
require_relative '../lib/include2ignore/include'


class Silence
  def puts(str)
    # Do nothing.
  end
end

class TestInclude2IgnoreElements < Test::Unit::TestCase
  def setup
    @element = Include2Ignore::Include::Element.new
    Include2Ignore::Warnings.output(Silence.new)
  end

  def teardown
    Include2Ignore::Warnings.output(nil)
  end

  def test_initialize_attributes
    assert_equal([], @element.items)
    assert_equal(:filedir, @element.category)
    @element.close
  end

  def test_push_basic_char
    @element.push('a')
    assert_equal(['a'], @element.items)
  end

  def test_push_skip_char
    assert_equal(:skip, @element.push('\\'))
    assert_equal('a', @element.push('a'))
    @element.close
    assert_nil(@element.items)
    assert_equal(/^a$/, @element.re)
  end

  def test_push_end_mark
    @element.push('/')
    assert_nil(@element.items)
    assert_equal(:filedir, @element.category)
  end

  def test_close_empty_pattern
    @element.close
    assert_nil(@element.items)
    assert_equal(:empty, @element.re)
  end

  def test_push_asterisk_any_conversion
    @element.push('*')
    @element.push('*')
    @element.close
    assert_equal(:anydirs, @element.re)
  end

  def test_close_regular_pattern
    @element.push('a')
    @element.push('*')
    @element.push('b')
    @element.close
    assert_match(/^a.*b$/.to_s, @element.re.to_s)
  end

  def test_close_pattern_with_wildcards
    @element.push('file')
    @element.push('*')
    @element.push('name')
    @element.close
    assert_equal(/^file.*name$/.to_s, @element.re.to_s)
  end

  def test_close_trailing_backslash
    @element.push('a')
    @element.push('b')
    @element.push('\\')
    @element.close
    assert_equal(/^ab$/.to_s, @element.re.to_s)
  end

  def test_close_directory_pattern
    @element.push('src')
    @element.push('/')
    assert_nil(@element.items)
    assert_equal(:dir, @element.category)
    assert_equal(/^src$/.to_s, @element.re.to_s)
  end

  def test_close_duplicate_asterisk
    @element.push('a')
    @element.push('*')
    @element.push('*')
    @element.push('b')
    @element.close
    assert_equal(/^a.*b$/.to_s, @element.re.to_s)
  end

  def test_push_after_close_raises_error
    @element.push('a')
    @element.close
    assert_raise(StandardError) { @element.push('b') }
  end

  def test_escaped_slash
    @element.push('a')
    @element.push('\\')
    @element.push('/')
    @element.push('b')
    @element.close
    assert_equal(%r{^a/b$}.to_s, @element.re.to_s)
  end
end

class TestInclude2IgnoreRule < Test::Unit::TestCase
  def setup
    Include2Ignore::Warnings.output(Silence.new)
  end

  def teardown
    Include2Ignore::Warnings.output(nil)
  end

  def test_initialize_normal_include
    rule = Include2Ignore::Include::Rule.new('  dir/file')
    assert_equal(:include, rule.kind)
    assert_equal(2, rule.elements.size)
  end

  def test_initialize_exclusion
    rule = Include2Ignore::Include::Rule.new('!src')
    assert_equal(:exclude, rule.kind)
    assert_equal(1, rule.elements.size)
  end

  def test_initialize_comment
    rule = Include2Ignore::Include::Rule.new('# comment')
    assert_equal(:comment, rule.kind)
    assert_equal(0, rule.elements.size)
  end

  def test_initialize_empty_line
    rule = Include2Ignore::Include::Rule.new('')
    assert_equal(:comment, rule.kind)
    assert_equal(0, rule.elements.size)
  end

  def test_initialize_normal_pattern
    rule = Include2Ignore::Include::Rule.new('test.txt')
    assert_equal(:include, rule.kind)
    assert_equal(1, rule.elements.size)
  end

  def test_initialize_pattern_with_wildcards
    rule = Include2Ignore::Include::Rule.new('file*.txt')
    assert_equal(:include, rule.kind)
    assert_equal(1, rule.elements.size)
  end

  def test_initialize_exclusion_with_pattern
    rule = Include2Ignore::Include::Rule.new('!pattern*')
    assert_equal(:exclude, rule.kind)
    assert_equal(1, rule.elements.size)
  end

  def test_elements_process_characters
    rule = Include2Ignore::Include::Rule.new('a b c')
    refute_nil(rule.elements)
  end
end

class TestInclude2IgnoreProcessedElement < Test::Unit::TestCase
  def setup
    @pe = Include2Ignore::Include::ProcessedElement
    @rule = Include2Ignore::Include
    @file = @rule::FILE
    @dir = @rule::DIR
    @filedir = Include2Ignore::Include::Element::FILEDIR
  end

  def test_attributes
    element = @pe.new(/name/, @file)
    assert_equal(/name/, element.re)
    assert_equal(@file, element.category)
  end

  def test_anydirs_requires_directory_category
    assert_raise(ArgumentError) { @pe.new(:anydirs, @file) }
  end

  def test_matches_regexp
    element = @pe.new(/name/, @file)
    assert(element.match?('name', @file))
    refute(element.match?('other', @file))
  end

  def test_directory_category_rejects_file
    element = @pe.new(/^src$/, @dir)
    refute(element.match?('src', @file))
    assert(element.match?('src', @dir))
  end

  def test_file_category_rejects_directory
    element = @pe.new(/^src$/, @file)
    refute(element.match?('src', @dir))
    assert(element.match?('src', @file))
  end

  def test_anydirs_matches_any_directory
    element = @pe.new(:anydirs, @dir)
    assert(element.match?('anything', @dir))
    assert(element.match?('', @dir))
  end

  def test_anydirs_does_not_match_file
    element = @pe.new(:anydirs, @dir)
    refute(element.match?('anything', @file))
  end

  def test_empty_re_matches_empty_string
    element = @pe.new(:empty, @file)
    assert(element.match?('', @file))
  end

  def test_empty_re_rejects_nonempty_string
    element = @pe.new(:empty, @file)
    refute(element.match?('x', @file))
  end

  def test_invalid_category_raises
    element = @pe.new(/^x$/, @file)
    assert_raise(ArgumentError) { element.match?('x', :not_a_category) }
  end
end

class TestInclude2IgnoreAnchoredRule < Test::Unit::TestCase
  def setup
    @rule = Include2Ignore::Include
    @processed = @rule::ProcessedElement
    @anchored = @rule::AnchoredRule
    @file = @rule::FILE
    @dir = @rule::DIR
    Include2Ignore::Warnings.output(Silence.new)
  end

  def teardown
    Include2Ignore::Warnings.output(nil)
  end

  def element(regexp, category = @dir)
    @processed.new(regexp, category)
  end

  def test_attributes
    anchored = @anchored.new([ element(/^\d+$/, @dir) ], true)
    assert_equal(1, anchored.elements.size)
    assert_equal(1, anchored.first_anydirs)
    s = anchored.to_s
    assert_true(s.is_a?(String))
    refute(s.empty?)
  end

  def test_first_anydirs_index_when_none
    anchored = @anchored.new([ element(/^a$/, @dir), element(/^b$/, @file) ], true)
    assert_equal(2, anchored.first_anydirs)
  end

  def test_first_anydirs_index_when_leading_anydirs
    anchored = @anchored.new([ @processed.new(:anydirs, @dir) ], true)
    assert_equal(0, anchored.first_anydirs)
  end

  def test_two_elements_match
    anchored = @anchored.new([ element(/^src$/, @dir), element(/^main\.rb$/, @file) ], true)
    assert(anchored.match?(['src', 'main.rb'], @file))
  end

  def test_two_elements_last_mismatch
    anchored = @anchored.new([ element(/^src$/, @dir), element(/^main\.rb$/, @file) ], true)
    refute(anchored.match?(['src', 'other.rb'], @file))
  end

  def test_path_too_short
    anchored = @anchored.new([ element(/^src$/, @dir), element(/^main\.rb$/, @file) ], true)
    refute(anchored.match?(['src'], @file))
  end

  def test_path_too_long_without_anydirs
    anchored = @anchored.new([ element(/^src$/, @dir), element(/^main\.rb$/, @file) ], true)
    refute(anchored.match?(%w[x y z], @file))
  end

  def test_first_element_mismatch
    anchored = @anchored.new([ element(/^a$/, @dir), element(/^b$/, @dir), element(/^c$/, @file) ], true)
    refute(anchored.match?(%w[x b c], @file))
  end

  def test_middle_element_mismatch
    anchored = @anchored.new([ element(/^a$/, @dir), element(/^b$/, @dir), element(/^c$/, @file) ], true)
    refute(anchored.match?(%w[a x c], @file))
  end

  def test_anydirs_in_middle_requires_one_directory
    anchored = @anchored.new([ element(/^a$/, @dir), element(:anydirs, @dir), element(/^c$/, @file) ], true)
    refute(anchored.match?(%w[a c], @file))
    assert(anchored.match?(%w[a x c], @file))
  end

  def test_anydirs_in_middle_absorbs_multiple_directories
    anchored = @anchored.new([ element(/^a$/, @dir), element(:anydirs, @dir), element(/^c$/, @file) ], true)
    assert(anchored.match?(%w[a x y c], @file))
  end

  def test_anydirs_at_start_requires_one_directory
    anchored = @anchored.new([ element(:anydirs, @dir), element(/^test.txt$/, @file) ], true)
    refute(anchored.match?(['test.txt'], @file))
    assert(anchored.match?(['a', 'b', 'test.txt'], @file))
  end

  def test_asterisk_file
    anchored = @anchored.new([ element(@rule::ANY_ONE, @file) ], false)
    refute(anchored.match?(['a', 'b', 'c'], @dir))
    refute(anchored.match?(['b', 'c'], @dir))
    refute(anchored.match?(['c'], @dir))
    refute(anchored.match?(['a', 'b', 'test.txt'], @file))
    refute(anchored.match?(['a', 'test.txt'], @file))
    assert(anchored.match?(['test.txt'], @file))
  end

  def test_asterisk_dir
    anchored = @anchored.new([ element(@rule::ANY_ONE, @dir) ], false)
    refute(anchored.match?(['a', 'b', 'c'], @dir))
    refute(anchored.match?(['b', 'c'], @dir))
    assert(anchored.match?(['c'], @dir))
    refute(anchored.match?(['a', 'b', 'test.txt'], @file))
    refute(anchored.match?(['a', 'test.txt'], @file))
    refute(anchored.match?(['test.txt'], @file))
  end

  def test_asterisk_anydir_file
    anchored = @anchored.new([ element(:anydirs, @dir), element(@rule::ANY_ONE, @file) ], false)
    refute(anchored.match?(['a', 'b', 'c'], @dir))
    refute(anchored.match?(['b', 'c'], @dir))
    refute(anchored.match?(['c'], @dir))
    assert(anchored.match?(['a', 'b', 'test.txt'], @file))
    assert(anchored.match?(['a', 'test.txt'], @file))
    refute(anchored.match?(['test.txt'], @file))
  end

  def test_asterisk_dir_anydir
    anchored = @anchored.new([ element(@rule::ANY_ONE, @dir), element(:anydirs, @dir) ], false)
    assert(anchored.match?(['a', 'b', 'c'], @dir))
    assert(anchored.match?(['b', 'c'], @dir))
    refute(anchored.match?(['c'], @dir))
    refute(anchored.match?(['a', 'b', 'test.txt'], @file))
    refute(anchored.match?(['a', 'test.txt'], @file))
    refute(anchored.match?(['test.txt'], @file))
  end

  def test_remove_empties
    rule = Include2Ignore::Include::Rule.new('src//lib//*.rb')
    anchored = rule.anchored
    assert_equal(4, anchored.size)
    assert(anchored[0].match?(['src', 'lib', 'x.rb'], @file))
    refute(anchored[0].match?(['src', 'foo', 'x.rb'], @file))
  end

  def test_derived_from_rule_multi_directory
    rule = Include2Ignore::Include::Rule.new('src/**/*.rb')
    anchored = rule.anchored
    assert_equal(4, anchored.size)
    assert(anchored[0].match?(['src', 'lib', 'x.rb'], @file))
    refute(anchored[0].match?(['src', 'x.rb'], @file))
  end

  def test_leading_slash_anchors_to_root
    rule = Include2Ignore::Include::Rule.new('/src/test.rb')
    anchored = rule.anchored
    assert_equal(2, anchored.size)
    assert(anchored[0].match?(['src', 'test.rb'], @file))
    refute(anchored[0].match?(['test.rb'], @file))
  end

  def test_wildcard_produces_rooted_variants
    rule = Include2Ignore::Include::Rule.new('file*name.txt')
    anchored = rule.anchored
    assert_equal(4, anchored.size)
    assert(anchored[0].match?(['fileXname.txt'], @file))
    assert(anchored[2].match?(['d1', 'fileXname.txt'], @file))
  end

  def test_double_anydir_join
    rule = Include2Ignore::Include::Rule.new('/**/**/')
    anchored = rule.anchored
    assert_equal(1, anchored.size)
    anchored = anchored.first
    assert_false(anchored.exclude)
    assert_equal(2, anchored.elements.size) # ANY_ONE and :anydirs.
    assert_equal(Include2Ignore::Include::ANY_ONE.object_id, anchored.elements.first.re.object_id)
    assert_equal(:anydirs, anchored.elements.last.re)
  end

  def test_anydir_anyone_swap
    rule = Include2Ignore::Include::Rule.new('/**/*/')
    anchored = rule.anchored
    assert_equal(1, anchored.size)
    anchored = anchored.first
    assert_false(anchored.exclude)
    assert_equal(2, anchored.elements.size) # ANY_ONE and :anydirs.
    assert_equal(Include2Ignore::Include::ANY_ONE.object_id, anchored.elements.first.re.object_id)
    assert_equal(:anydirs, anchored.elements.last.re)
  end

  def test_long_paths
    rule = Include2Ignore::Include::Rule.new('/**/c/*/fixed/')
    anchored = rule.anchored
    assert_equal(1, anchored.size)
    assert(anchored.first.match?(%w[a b c d fixed], @dir))
    refute(anchored.first.match?(%w[a b c d fixed], @file))
  end
end

class TestInclude2IgnoreModule < Test::Unit::TestCase
  def test_doc
    s = Include2Ignore::Include.doc
    assert(s.is_a?(String))
    refute(s.empty?)
  end
end

class TestInclude2IgnoreClassifier < Test::Unit::TestCase
  def setup
    @classifier = Include2Ignore::Include::Classifier.new
    Include2Ignore::Warnings.output(Silence.new)
  end

  def teardown
    Include2Ignore::Warnings.output(nil)
  end

  def test_initialize_rules
    assert_equal([], @classifier.rules)
  end

  def test_add_include_rule
    @classifier.add('dir/file')
    assert_equal(4, @classifier.rules.size) # 2 anchored * (dir + file)
    @classifier.rules.each { |r| assert_false(r.exclude) }
  end

  def test_add_exclude_rule
    @classifier.add('!src')
    assert_equal(4, @classifier.rules.size) # 2 anchored * (dir + file)
    @classifier.rules.each { |r| assert_true(r.exclude) }
  end

  def test_add_comment_ignored
    @classifier.add('# comment')
    assert_equal(0, @classifier.rules.size)
  end

  def test_add_empty_ignored
    @classifier.add('')
    assert_equal(0, @classifier.rules.size)
  end

  def test_close
    @classifier.add('a')
    @classifier.close
    assert_equal(4, @classifier.rules.size) # 2 anchored * (dir + file)
    assert(@classifier.rules.frozen?)
  end

  def test_exclude_matching_include
    @classifier.add('dir/file')
    @classifier.close
    # Rules are reversed: [**/dir/file, dir/file]
    # Rule 1 matches 'dir/file'. Returns r.exclude (false).
    assert_equal(false, @classifier.exclude(%w[dir file], Include2Ignore::Include::FILE))
  end

  def test_exclude_matching_exclude
    @classifier.add('!src')
    @classifier.close
    # Rule is [src], exclude is true.
    assert_equal(true, @classifier.exclude(['src'], Include2Ignore::Include::FILE))
  end

  def test_exclude_no_match_file
    @classifier.add('other')
    @classifier.close
    assert_nil(@classifier.exclude(['src'], Include2Ignore::Include::FILE))
  end

  def test_exclude_no_match_dir
    @classifier.add('other')
    @classifier.close
    # No matching rule, category is DIR. Returns nil.
    assert_nil(@classifier.exclude(['src'], Include2Ignore::Include::DIR))
  end

  def test_exclude_first_match_wins
    @classifier.add('include_me')
    @classifier.add('!exclude_me')
    @classifier.close
    # Rules are reversed: [!exclude_me, include_me]

    # 'exclude_me' matches Rule 1. Rule 1.exclude is true. Returns true.
    assert_true(@classifier.exclude(['exclude_me'], Include2Ignore::Include::FILE))

    # 'include_me' does not match Rule 1.
    # 'include_me' matches Rule 2. Rule 2.exclude is false. Returns false.
    assert_false(@classifier.exclude(['include_me'], Include2Ignore::Include::FILE))
    assert_nil(@classifier.exclude(['something else'], Include2Ignore::Include::FILE))
    assert_nil(@classifier.exclude(['something else'], Include2Ignore::Include::DIR))
  end
end
