# frozen_string_literal: true

# Copyright © 2026 Ismo Kärkkäinen
# Licensed under Universal Permissive License. See LICENSE.txt.

require 'yaml'


module Include2Ignore
  # Configuration file handling.
  module IgnoreConfiguration
    # Built-in configs to be dumped outside.
    ALL = <<EOF
include_majority:
  include: '#' # Include lines as comments.
  ignore: '' # Ignore lines have no prefix.
EOF

    DEFAULT = <<EOF
include_majority:
  include: false # Include lines omitted.
  ignore: '' # Ignore lines have no prefix.
EOF

    DOCKER = <<EOF
include_majority: # More included files than ignored.
  include: false # Include lines omitted.
  ignore: '' # Ignore lines have no prefix.
ignore_majority: # More ignored files, flip for smaller file.
  header: '*' # Start with ignore everything.
  include: '!' # Includes are exceptions to ignore all.
  ignore: false # Header covers everything.
EOF

    DEFAULT_FORMAT = :default
    BUILTINS = {
      all: ALL,
      default: DEFAULT,
      docker: DOCKER
    }.freeze

    def self.doc
      <<EOF
If FORMAT is a file name it is read. Otherwise internal format is used.
Internal formats: #{BUILTINS.keys.sort!.join(', ')}. Defaults to "#{DEFAULT_FORMAT}".

If format allows, ignore file may ignore everything and add exceptions if that
produces a file with fewer entries. Dump internal format "docker" for info.
EOF
    end

    def self.get(name)
      BUILTINS[name.downcase.to_sym]
    end

    # Reads from file, or from built-ins, or provides default if name is nil.
    def self.read(name)
      return YAML.safe_load(BUILTINS[DEFAULT_FORMAT]) if name.nil?
      begin
        YAML.safe_load_file(name)
      rescue StandardError
        YAML.safe_load(get(name))
      end
    end

    def self.write(nil_filename_or_has_puts_string, format)
      fmt = get(format)
      unless fmt.nil?
        if nil_filename_or_has_puts_string.nil?
          output = $stdout
        elsif nil_filename_or_has_puts_string.is_a?(String)
          output = File.new(nil_filename_or_has_puts_string, 'wt')
        elsif nil_filename_or_has_puts_string.respond_to?(:puts)
          output = nil_filename_or_has_puts_string
        else
          raise ArgumentError, 'Include2Ignore::IgnoreConfiguration::write: Not nil, string, nor puts in argument'
        end
        output.puts(fmt)
      end
      fmt
    end

    # Contains per-line configuration.
    class Configuration
      attr_reader :keep, :drop, :header

      def initialize(config)
        @keep = config.fetch('include', false)
        @drop = config.fetch('ignore', false)
        @header = config['header']
      end
    end

    # Handles configuration file contents and selection of applicable config.
    class ConfigurationAlternatives
      attr_reader :include_majority, :ignore_majority

      def initialize(config)
        raise ArgumentError, 'Not a hash' unless config.is_a?(Hash)
        @include_majority = config.key?('include_majority') ? Configuration.new(config['include_majority']) : nil
        @ignore_majority = config.key?('ignore_majority') ? Configuration.new(config['ignore_majority']) : nil
        raise ArgumentError, 'No majority configurations.' if @include_majority.nil? && @ignore_majority.nil?
      end

      def select(include_count, ignore_count)
        return @include_majority if @ignore_majority.nil?
        return @ignore_majority if @include_majority.nil?
        include_count < ignore_count ? @ignore_majority : @include_majority
      end
    end
  end
end
