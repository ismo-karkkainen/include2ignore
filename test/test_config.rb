# frozen_string_literal: true

# Tests for the Include2Ignore::IgnoreConfiguration module
# Tests by OpenCode/glm-4.7-flash/Ollama.

require 'test/unit'
require 'tempfile'
require 'fileutils'
require_relative '../lib/include2ignore/config'

class TestIgnoreConfiguration < Test::Unit::TestCase
  # Test the ALL configuration constant
  def test_all_constant
    expected = <<~YAML
      include_majority:
        include: '#' # Include lines as comments.
        ignore: '' # Ignore lines have no prefix.
    YAML
    expected = expected.strip
    assert_equal(expected, Include2Ignore::IgnoreConfiguration::ALL.to_s.strip)
  end

  # Test the DEFAULT configuration constant
  def test_default_constant
    expected = <<~YAML
      include_majority:
        include: false # Include lines omitted.
        ignore: '' # Ignore lines have no prefix.
    YAML
    expected = expected.strip
    assert_equal(expected, Include2Ignore::IgnoreConfiguration::DEFAULT.to_s.strip)
  end

  # Test the DOCKER configuration constant
  def test_docker_constant
    expected = <<~YAML
      include_majority: # More included files than ignored.
        include: false # Include lines omitted.
        ignore: '' # Ignore lines have no prefix.
      ignore_majority: # More ignored files, flip for smaller file.
        header: '*' # Start with ignore everything.
        include: '!' # Includes are exceptions to ignore all.
        ignore: false # Header covers everything.
    YAML
    expected = expected.strip
    assert_equal(expected, Include2Ignore::IgnoreConfiguration::DOCKER.to_s.strip)
  end

  # Test BUILTINS contains expected keys
  def test_builtins_has_expected_keys
    expected_keys = [:all, :default, :docker]
    assert_equal(expected_keys, Include2Ignore::IgnoreConfiguration::BUILTINS.keys.sort)
  end

  # Test BUILTINS has expected content
  def test_builtins_all_has_content
    assert_kind_of(Hash, YAML.load(Include2Ignore::IgnoreConfiguration::BUILTINS[:all]))
  end

  # Test BUILTINS has expected content
  def test_builtins_default_has_content
    assert_kind_of(Hash, YAML.load(Include2Ignore::IgnoreConfiguration::BUILTINS[:default]))
  end

  # Test BUILTINS has expected content
  def test_builtins_docker_has_content
    assert_kind_of(Hash, YAML.load(Include2Ignore::IgnoreConfiguration::BUILTINS[:docker]))
  end

  def test_doc
    assert(Include2Ignore::IgnoreConfiguration.doc.is_a?(String))
  end

  def test_get_valid
    assert_equal(Include2Ignore::IgnoreConfiguration::ALL, Include2Ignore::IgnoreConfiguration.get('aLl'))
  end

  def test_get_missing
    assert_nil(Include2Ignore::IgnoreConfiguration.get('sjdhsdkjhfalksh'))
  end

  # Test read returns default when name is nil
  def test_read_with_nil_returns_default
    result = Include2Ignore::IgnoreConfiguration.read(nil)
    assert_equal(false, result['include_majority']['include'])
    assert_equal('', result['include_majority']['ignore'])
  end

  # Test read reads from actual file when valid path provided
  def test_read_valid_file
    temp = Tempfile.new('config_test')
    begin
      temp.puts <<~YAML
        custom_config:
          include: true
          ignore: '-'
      YAML
      temp.flush

      result = Include2Ignore::IgnoreConfiguration.read(temp.path)
      assert_equal(true, result['custom_config']['include'])
      assert_equal('-', result['custom_config']['ignore'])
    ensure
      temp&.close
      temp.unlink if temp && !temp.closed?
    end
  end

  def test_read_internal
    expected = Include2Ignore::IgnoreConfiguration::DOCKER
    result = Include2Ignore::IgnoreConfiguration.read('docker')
    assert_equal(YAML.safe_load(expected), result)
  end

  class MockOutput
    attr_reader :saved
    def initialize
      @saved = ''
    end

    def puts(content)
      @saved = content
    end

    def write(content)
      @saved = content
    end
  end

  def test_write_internal
    out = MockOutput.new
    expected = Include2Ignore::IgnoreConfiguration::DOCKER
    result = Include2Ignore::IgnoreConfiguration.write(out, 'docker')
    assert_equal(expected, out.saved)
    assert_equal(expected, result)
  end

  def test_write_file
    name = 'test/tmp.yaml'
    expected = Include2Ignore::IgnoreConfiguration::DOCKER
    result = Include2Ignore::IgnoreConfiguration.write(name, 'docker')
    assert_equal(expected, result)
    assert(File.exist?(name))
    File.unlink(name)
  end

  def test_write_stdout
    expected = Include2Ignore::IgnoreConfiguration::DOCKER
    out = MockOutput.new
    orig = $stdout
    $stdout = out
    result = Include2Ignore::IgnoreConfiguration.write(nil, 'docker')
    $stdout = orig
    assert_equal(expected, out.saved)
    assert_equal(expected, result)
  end

  def test_write_raise
    assert_raise(ArgumentError) { Include2Ignore::IgnoreConfiguration.write({}, 'all') }
  end

  def test_write_invalid
    assert_nil(Include2Ignore::IgnoreConfiguration.write({}, 'akfjhlakgsjfh'))
  end

  # Test Configuration initialization with valid hash
  def test_configuration_initialization_with_valid_hash
    config = Include2Ignore::IgnoreConfiguration::Configuration.new(
      'include' => true,
      'ignore' => '-',
      'header' => '*'
    )
    assert_equal(true, config.keep)
    assert_equal('-', config.drop)
    assert_equal('*', config.header)
  end

  # Test Configuration initializes with false for missing include
  def test_configuration_ignores_missing_include
    config = Include2Ignore::IgnoreConfiguration::Configuration.new(
      'ignore' => '-'
    )
    assert_equal(false, config.keep)
    assert_equal('-', config.drop)
  end

  # Test Configuration initializes with false for missing ignore
  def test_configuration_ignores_missing_ignore
    config = Include2Ignore::IgnoreConfiguration::Configuration.new(
      'include' => true
    )
    assert_equal(true, config.keep)
    assert_equal(false, config.drop)
  end

  # Test Configuration initializes with nil for missing header
  def test_configuration_ignores_missing_header
    config = Include2Ignore::IgnoreConfiguration::Configuration.new(
      'include' => true,
      'ignore' => '-'
    )
    assert_equal(true, config.keep)
    assert_equal('-', config.drop)
    assert_nil(config.header)
  end

  # Test ConfigurationAlternatives initializes with include_majority
  def test_configuration_alternatives_with_include_majority
    config = {
      'include_majority' => {
        'include' => true,
        'ignore' => '-'
      }
    }
    result = Include2Ignore::IgnoreConfiguration::ConfigurationAlternatives.new(config)
    assert_not_nil(result.include_majority)
    assert_nil(result.ignore_majority)
    assert_equal(true, result.include_majority.keep)
    assert_equal('-', result.include_majority.drop)
    assert_nil(result.include_majority.header)
  end

  # Test ConfigurationAlternatives initializes with ignore_majority
  def test_configuration_alternatives_with_ignore_majority
    config = {
      'ignore_majority' => {
        'include' => false,
        'ignore' => '*'
      }
    }
    result = Include2Ignore::IgnoreConfiguration::ConfigurationAlternatives.new(config)
    assert_nil(result.include_majority)
    assert_not_nil(result.ignore_majority)
    assert_equal(false, result.ignore_majority.keep)
    assert_equal('*', result.ignore_majority.drop)
  end

  # Test ConfigurationAlternatives initializes with both configurations
  def test_configuration_alternatives_with_both
    config = {
      'include_majority' => {
        'include' => true,
        'ignore' => '-'
      },
      'ignore_majority' => {
        'include' => false,
        'ignore' => '*'
      }
    }
    result = Include2Ignore::IgnoreConfiguration::ConfigurationAlternatives.new(config)
    assert_not_nil(result.include_majority)
    assert_not_nil(result.ignore_majority)
  end

  # Test ConfigurationAlternatives raises ArgumentError when not a hash
  def test_configuration_alternatives_raises_on_non_hash
    assert_raise(ArgumentError, 'Not a hash') do
      Include2Ignore::IgnoreConfiguration::ConfigurationAlternatives.new('not a hash')
    end
  end

  # Test ConfigurationAlternatives raises ArgumentError when no majority configurations
  def test_configuration_alternatives_raises_when_no_majority
    config = {
      'neither' => {
        'include' => false
      }
    }
    assert_raise(ArgumentError, 'No majority configurations.') do
      Include2Ignore::IgnoreConfiguration::ConfigurationAlternatives.new(config)
    end
  end

  # Test ConfigurationAlternatives raises ArgumentError for empty config
  def test_configuration_alternatives_raises_on_empty_config
    assert_raise(ArgumentError, 'No majority configurations.') do
      Include2Ignore::IgnoreConfiguration::ConfigurationAlternatives.new({})
    end
  end

  # Test ConfigurationAlternatives select returns include_majority when ignore is nil
  def test_select_returns_include_majority_when_ignore_nil
    config = {
      'include_majority' => {
        'include' => true,
        'ignore' => '-'
      }
    }
    result = Include2Ignore::IgnoreConfiguration::ConfigurationAlternatives.new(config)
    configuration = result.select(5, 3)
    assert_equal(result.include_majority, configuration)
  end

  # Test ConfigurationAlternatives select returns ignore_majority when include is nil
  def test_select_returns_ignore_majority_when_include_nil
    config = {
      'ignore_majority' => {
        'include' => true,
        'ignore' => '-'
      }
    }
    result = Include2Ignore::IgnoreConfiguration::ConfigurationAlternatives.new(config)
    configuration = result.select(3, 5)
    assert_equal(result.ignore_majority, configuration)
  end

  # Test ConfigurationAlternatives select picks include when counts are equal
  def test_select_picks_include_when_equal_counts
    config = {
      'include_majority' => {
        'include' => true,
        'ignore' => '-'
      },
      'ignore_majority' => {
        'include' => false,
        'ignore' => '*'
      }
    }
    result = Include2Ignore::IgnoreConfiguration::ConfigurationAlternatives.new(config)
    # When counts are equal (2 vs 2), should pick include_majority
    configuration = result.select(2, 2)
    assert_equal(result.include_majority, configuration)
  end

  # Test ConfigurationAlternatives select correctly identifies more includes
  def test_select_identifies_more_includes
    config = {
      'include_majority' => {
        'include' => true,
        'ignore' => '-'
      },
      'ignore_majority' => {
        'include' => false,
        'ignore' => '*'
      }
    }
    result = Include2Ignore::IgnoreConfiguration::ConfigurationAlternatives.new(config)
    # More includes than ignores (5 vs 3)
    configuration = result.select(5, 3)
    assert_equal(result.include_majority, configuration)
  end

  # Test ConfigurationAlternatives select correctly identifies more ignores
  def test_select_identifies_more_ignores
    config = {
      'include_majority' => {
        'include' => true,
        'ignore' => '-'
      },
      'ignore_majority' => {
        'include' => false,
        'ignore' => '*'
      }
    }
    result = Include2Ignore::IgnoreConfiguration::ConfigurationAlternatives.new(config)
    # More ignores than includes (3 vs 5)
    configuration = result.select(3, 5)
    assert_equal(result.ignore_majority, configuration)
  end
end