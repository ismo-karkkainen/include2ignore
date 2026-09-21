# frozen_string_literal: true

# Tests by OpenCode/gemma4:26b-nvfp4/Ollama.
# Human edits.

require 'test/unit'
require_relative '../lib/include2ignore/search'


class Silence
  def puts(str)
    # Do nothing.
  end
end

class TestDirectoryTraversal < Test::Unit::TestCase
  def setup
    `test/setup_fixtures.sh`
    @base_dir = File.expand_path('test/fixtures/search_test_dir')
    @link_dir = File.expand_path('test/fixtures/link_test_dir')
    @skip = Include2Ignore::Include::Classifier.new
    @skip.close
    Include2Ignore::Warnings.output(Silence.new)
  end

  def teardown
    `rm -rf test/fixtures`
    Include2Ignore::Search.dir_symlink_handling = :follow
    Include2Ignore::Search.file_symlink_handling = :check
    Include2Ignore::Warnings.output(nil)
  end

  def test_traversal_with_symlinks
    real_paths = Set.new
    results = []
    Include2Ignore::Search.traverse(@base_dir, @skip) do |path, _dir, _inv|
      traversed = File.join(@base_dir, *path)
      real_paths.add(traversed)
      assert(results.size < 100)
    end

    # 1. Normal files and their symlinks should all resolve to the same real path.
    assert_includes real_paths, File.join(@base_dir, 'regular_file.txt')
    assert_includes real_paths, File.join(@base_dir, 'subdir/subdir_file.txt')
    assert_includes real_paths, File.join(@base_dir, 'dir_a/file_a.txt')
    assert_includes real_paths, File.join(@base_dir, 'dir_a/link_to_dir_b/file_b.txt')

    # 2. Check for the outside symlink
    expected_outside = File.join(@base_dir, 'outside_symlink/hidden.txt')
    assert_includes real_paths, expected_outside
  end

  def test_traversal_entry
    file_path = File.join(@base_dir, 'regular_file.txt')
    entry = Include2Ignore::Search::TraversalEntry.new('file.txt', file_path)

    assert_equal('file.txt', entry.name)
    assert_equal(File.realpath(file_path), entry.full_name)
    assert_kind_of File::Stat, entry.stat
    assert_false entry.directory?

    # Test symlink to file
    symlink_path = File.join(@base_dir, 'symlink_to_file')
    entry_link = Include2Ignore::Search::TraversalEntry.new('link', symlink_path)
    assert_equal(symlink_path, entry_link.full_name)
    assert_false entry_link.directory?

    # Broken symlink.
    symlink_path = File.join(@link_dir, 'broken')
    entry_link = Include2Ignore::Search::TraversalEntry.new('link', symlink_path)
    assert_equal(symlink_path, entry_link.full_name)
    assert_false entry_link.directory?
    assert entry_link.reject?

    # Loop symlink.
    symlink_path = File.join(@link_dir, 'loop_1')
    entry_link = Include2Ignore::Search::TraversalEntry.new('link', symlink_path)
    assert_equal(symlink_path, entry_link.full_name)
    assert_false entry_link.directory?
    assert entry_link.reject?
  end

  def verify_path(results, relative_path_array, expected)
    found = results.find { |r| r[:path] == relative_path_array }
    if expected.nil?
      assert_nil found, "Path #{relative_path_array.inspect} should have been skipped"
    else
      assert found, "Path #{relative_path_array.inspect} should have been yielded"
      assert_equal expected, found[:reject], "Path #{relative_path_array.inspect} reject status mismatch"
    end
  end

  def get_results(dir_handling, file_handling)
    Include2Ignore::Search.dir_symlink_handling = dir_handling
    Include2Ignore::Search.file_symlink_handling = file_handling
    results = []
    Include2Ignore::Search.traverse(@link_dir, @skip) do |path, dir, reject|
      results << {
        path: path,
        directory: dir,
        reject: reject
      }
    end
    results
  end

  def test_reject_reject
    results = get_results(:reject, :reject)
    # 1. Broken or loop should ALWAYS be rejected and yielded.
    verify_path(results, ['broken'], true)
    verify_path(results, ['loop_1'], true)
    verify_path(results, ['loop_2'], true)
    # 2. Regular directory should ALWAYS be yielded with reject: false.
    verify_path(results, ['sd'], false)
    verify_path(results, ['subdir'], false)
    verify_path(results, ['subdir', 'dir_a', 'file_a1.txt'], false)

    verify_path(results, ['sbdr'], true)
    verify_path(results, ['sbdr', 'dir_a'], nil)
    verify_path(results, ['sd', 'dir_a'], true)
    verify_path(results, ['sd', 'dir_b'], true)

    verify_path(results, ['sd', 'dir_a', 'file_a5.txt'], nil) # Both links.
    verify_path(results, ['sd', 'dir_a', 'file_a3.md'], nil) # Dir link.
    verify_path(results, ['sd', 'dir_c', 'file_c5.txt'], true) # File link.
  end

  def test_reject_skip
    results = get_results(:reject, :skip)
    # 1. Broken or loop should ALWAYS be rejected and yielded.
    verify_path(results, ['broken'], true)
    verify_path(results, ['loop_1'], true)
    verify_path(results, ['loop_2'], true)
    # 2. Regular directory should ALWAYS be yielded with reject: false.
    verify_path(results, ['sd'], false)
    verify_path(results, ['subdir'], false)
    verify_path(results, ['subdir', 'dir_a', 'file_a1.txt'], false)

    verify_path(results, ['sbdr'], true)
    verify_path(results, ['sbdr', 'dir_a'], nil)
    verify_path(results, ['sd', 'dir_a'], true)
    verify_path(results, ['sd', 'dir_b'], true)

    verify_path(results, ['sd', 'dir_a', 'file_a5.txt'], nil) # Both links.
    verify_path(results, ['sd', 'dir_a', 'file_a3.md'], nil) # Dir link.
    verify_path(results, ['sd', 'dir_c', 'file_c5.txt'], nil) # File link.
  end

  def test_reject_check
    results = get_results(:reject, :check)
    # 1. Broken or loop should ALWAYS be rejected and yielded.
    verify_path(results, ['broken'], true)
    verify_path(results, ['loop_1'], true)
    verify_path(results, ['loop_2'], true)
    # 2. Regular directory should ALWAYS be yielded with reject: false.
    verify_path(results, ['sd'], false)
    verify_path(results, ['subdir'], false)
    verify_path(results, ['subdir', 'dir_a', 'file_a1.txt'], false)

    verify_path(results, ['sbdr'], true)
    verify_path(results, ['sbdr', 'dir_a'], nil)
    verify_path(results, ['sd', 'dir_a'], true)
    verify_path(results, ['sd', 'dir_b'], true)

    verify_path(results, ['sd', 'dir_a', 'file_a5.txt'], nil) # Both links.
    verify_path(results, ['sd', 'dir_a', 'file_a3.md'], nil) # Dir link.
    verify_path(results, ['sd', 'dir_c', 'file_c5.txt'], false) # File link.
  end

  def test_skip_reject
    results = get_results(:skip, :reject)
    # 1. Broken or loop should ALWAYS be rejected and yielded.
    verify_path(results, ['broken'], true)
    verify_path(results, ['loop_1'], true)
    verify_path(results, ['loop_2'], true)
    # 2. Regular directory should ALWAYS be yielded with reject: false.
    verify_path(results, ['sd'], false)
    verify_path(results, ['subdir'], false)
    verify_path(results, ['subdir', 'dir_a', 'file_a1.txt'], false)

    verify_path(results, ['sbdr'], nil)
    verify_path(results, ['sbdr', 'dir_a'], nil)
    verify_path(results, ['sd', 'dir_a'], nil)
    verify_path(results, ['sd', 'dir_b'], nil)

    verify_path(results, ['sd', 'dir_a', 'file_a5.txt'], nil) # Both links.
    verify_path(results, ['sd', 'dir_a', 'file_a3.md'], nil) # Dir link.
    verify_path(results, ['sd', 'dir_c', 'file_c5.txt'], true) # File link.
  end

  def test_skip_skip
    results = get_results(:skip, :skip)
    # 1. Broken or loop should ALWAYS be rejected and yielded.
    verify_path(results, ['broken'], true)
    verify_path(results, ['loop_1'], true)
    verify_path(results, ['loop_2'], true)
    # 2. Regular directory should ALWAYS be yielded with reject: false.
    verify_path(results, ['sd'], false)
    verify_path(results, ['subdir'], false)
    verify_path(results, ['subdir', 'dir_a', 'file_a1.txt'], false)

    verify_path(results, ['sbdr'], nil)
    verify_path(results, ['sbdr', 'dir_a'], nil)
    verify_path(results, ['sd', 'dir_a'], nil)
    verify_path(results, ['sd', 'dir_b'], nil)

    verify_path(results, ['sd', 'dir_a', 'file_a5.txt'], nil) # Both links.
    verify_path(results, ['sd', 'dir_a', 'file_a3.md'], nil) # Dir link.
    verify_path(results, ['sd', 'dir_c', 'file_c5.txt'], nil) # File link.
  end

  def test_skip_check
    results = get_results(:skip, :check)
    # 1. Broken or loop should ALWAYS be rejected and yielded.
    verify_path(results, ['broken'], true)
    verify_path(results, ['loop_1'], true)
    verify_path(results, ['loop_2'], true)
    # 2. Regular directory should ALWAYS be yielded with reject: false.
    verify_path(results, ['sd'], false)
    verify_path(results, ['subdir'], false)
    verify_path(results, ['subdir', 'dir_a', 'file_a1.txt'], false)

    verify_path(results, ['sbdr'], nil)
    verify_path(results, ['sbdr', 'dir_a'], nil)
    verify_path(results, ['sd', 'dir_a'], nil)
    verify_path(results, ['sd', 'dir_b'], nil)

    verify_path(results, ['sd', 'dir_a', 'file_a5.txt'], nil) # Both links.
    verify_path(results, ['sd', 'dir_a', 'file_a3.md'], nil) # Dir link.
    verify_path(results, ['sd', 'dir_c', 'file_c5.txt'], false) # File link.
  end

  def test_check_reject
    results = get_results(:check, :reject)
    # 1. Broken or loop should ALWAYS be rejected and yielded.
    verify_path(results, ['broken'], true)
    verify_path(results, ['loop_1'], true)
    verify_path(results, ['loop_2'], true)
    # 2. Regular directory should ALWAYS be yielded with reject: false.
    verify_path(results, ['sd'], false)
    verify_path(results, ['subdir'], false)
    verify_path(results, ['subdir', 'dir_a', 'file_a1.txt'], false)

    verify_path(results, ['sbdr'], false)
    verify_path(results, ['sbdr', 'dir_a'], nil)
    verify_path(results, ['sd', 'dir_a'], false)
    verify_path(results, ['sd', 'dir_b'], false)

    verify_path(results, ['sd', 'dir_a', 'file_a5.txt'], nil) # Both links.
    verify_path(results, ['sd', 'dir_a', 'file_a3.md'], nil) # Dir link.
    verify_path(results, ['sd', 'dir_c', 'file_c5.txt'], true) # File link.
  end

  def test_check_skip
    results = get_results(:check, :skip)
    # 1. Broken or loop should ALWAYS be rejected and yielded.
    verify_path(results, ['broken'], true)
    verify_path(results, ['loop_1'], true)
    verify_path(results, ['loop_2'], true)
    # 2. Regular directory should ALWAYS be yielded with reject: false.
    verify_path(results, ['sd'], false)
    verify_path(results, ['subdir'], false)
    verify_path(results, ['subdir', 'dir_a', 'file_a1.txt'], false)

    verify_path(results, ['sbdr'], false)
    verify_path(results, ['sbdr', 'dir_a'], nil)
    verify_path(results, ['sd', 'dir_a'], false)
    verify_path(results, ['sd', 'dir_b'], false)

    verify_path(results, ['sd', 'dir_a', 'file_a5.txt'], nil) # Both links.
    verify_path(results, ['sd', 'dir_a', 'file_a3.md'], nil) # Dir link.
    verify_path(results, ['sd', 'dir_c', 'file_c5.txt'], nil) # File link.
  end

  def test_check_check
    results = get_results(:check, :check)
    # 1. Broken or loop should ALWAYS be rejected and yielded.
    verify_path(results, ['broken'], true)
    verify_path(results, ['loop_1'], true)
    verify_path(results, ['loop_2'], true)
    # 2. Regular directory should ALWAYS be yielded with reject: false.
    verify_path(results, ['sd'], false)
    verify_path(results, ['subdir'], false)
    verify_path(results, ['subdir', 'dir_a', 'file_a1.txt'], false)

    verify_path(results, ['sbdr'], false)
    verify_path(results, ['sbdr', 'dir_a'], nil)
    verify_path(results, ['sd', 'dir_a'], false)
    verify_path(results, ['sd', 'dir_b'], false)

    verify_path(results, ['sd', 'dir_a', 'file_a5.txt'], nil) # Both links.
    verify_path(results, ['sd', 'dir_a', 'file_a3.md'], nil) # Dir link.
    verify_path(results, ['sd', 'dir_c', 'file_c5.txt'], false) # File link.
  end

  def test_follow_reject
    results = get_results(:follow, :reject)
    # 1. Broken or loop should ALWAYS be rejected and yielded.
    verify_path(results, ['broken'], true)
    verify_path(results, ['loop_1'], true)
    verify_path(results, ['loop_2'], true)
    # 2. Regular directory should ALWAYS be yielded with reject: false.
    verify_path(results, ['sd'], false)
    verify_path(results, ['subdir'], false)
    verify_path(results, ['subdir', 'dir_a', 'file_a1.txt'], false)

    verify_path(results, ['sbdr'], false)
    verify_path(results, ['sbdr', 'dir_a'], false)
    verify_path(results, ['sd', 'dir_a'], false)
    verify_path(results, ['sd', 'dir_b'], false)

    verify_path(results, ['sd', 'dir_a', 'file_a5.txt'], true) # Both links.
    verify_path(results, ['sd', 'dir_a', 'file_a3.md'], false) # Dir link.
    verify_path(results, ['sd', 'dir_c', 'file_c5.txt'], true) # File link.
  end

  def test_follow_skip
    results = get_results(:follow, :skip)
    # 1. Broken or loop should ALWAYS be rejected and yielded.
    verify_path(results, ['broken'], true)
    verify_path(results, ['loop_1'], true)
    verify_path(results, ['loop_2'], true)
    # 2. Regular directory should ALWAYS be yielded with reject: false.
    verify_path(results, ['sd'], false)
    verify_path(results, ['subdir'], false)
    verify_path(results, ['subdir', 'dir_a', 'file_a1.txt'], false)

    verify_path(results, ['sbdr'], false)
    verify_path(results, ['sbdr', 'dir_a'], false)
    verify_path(results, ['sd', 'dir_a'], false)
    verify_path(results, ['sd', 'dir_b'], false)

    verify_path(results, ['sd', 'dir_a', 'file_a5.txt'], nil) # Both links.
    verify_path(results, ['sd', 'dir_a', 'file_a3.md'], false) # Dir link.
    verify_path(results, ['sd', 'dir_c', 'file_c5.txt'], nil) # File link.
  end

  def test_follow_check
    results = get_results(:follow, :check)
    # 1. Broken or loop should ALWAYS be rejected and yielded.
    verify_path(results, ['broken'], true)
    verify_path(results, ['loop_1'], true)
    verify_path(results, ['loop_2'], true)
    # 2. Regular directory should ALWAYS be yielded with reject: false.
    verify_path(results, ['sd'], false)
    verify_path(results, ['subdir'], false)
    verify_path(results, ['subdir', 'dir_a', 'file_a1.txt'], false)

    verify_path(results, ['sbdr'], false)
    verify_path(results, ['sbdr', 'dir_a'], false)
    verify_path(results, ['sd', 'dir_a'], false)
    verify_path(results, ['sd', 'dir_b'], false)

    verify_path(results, ['sd', 'dir_a', 'file_a5.txt'], false) # Both links.
    verify_path(results, ['sd', 'dir_a', 'file_a3.md'], false) # Dir link.
    verify_path(results, ['sd', 'dir_c', 'file_c5.txt'], false) # File link.
  end

  def test_skip
    skip = Include2Ignore::Include::Classifier.new
    skip.add('/sbdr')
    skip.add('/**/*.md')
    skip.close
    Include2Ignore::Search.dir_symlink_handling = :follow
    Include2Ignore::Search.file_symlink_handling = :check
    results = []
    Include2Ignore::Search.traverse(@link_dir, skip) do |path, dir, reject|
      results << {
        path: path,
        directory: dir,
        reject: reject
      }
    end
    # 1. Broken or loop should ALWAYS be rejected and yielded.
    verify_path(results, ['broken'], true)
    verify_path(results, ['loop_1'], true)
    verify_path(results, ['loop_2'], true)
    # 2. Regular directory should ALWAYS be yielded with reject: false.
    verify_path(results, ['sd'], false)
    verify_path(results, ['subdir'], false)
    verify_path(results, ['subdir', 'dir_a', 'file_a1.txt'], false)

    verify_path(results, ['sbdr'], nil)
    verify_path(results, ['sbdr', 'dir_a'], nil)
    verify_path(results, ['sd', 'dir_a'], false)
    verify_path(results, ['sd', 'dir_b'], false)

    verify_path(results, ['sd', 'dir_a', 'file_a5.txt'], false) # Both links.
    verify_path(results, ['sd', 'dir_a', 'file_a3.md'], nil) # Dir link.
    verify_path(results, ['sd', 'dir_c', 'file_c5.txt'], false) # File link.
  end

  def test_doc
    assert(Include2Ignore::Search.doc.is_a?(String))
  end
end
