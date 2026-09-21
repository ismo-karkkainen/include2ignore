# frozen_string_literal: true

# Copyright © 2026 Ismo Kärkkäinen
# Licensed under Universal Permissive License. See LICENSE.txt.

module Include2Ignore
  # Writes to ignore file, output object, or standard output.
  class Ignore
    attr_reader :output, :puts_include, :puts_exclude

    def initialize(nil_filename_or_has_puts_string, config)
      if nil_filename_or_has_puts_string.nil?
        @output = $stdout
      elsif nil_filename_or_has_puts_string.is_a?(String)
        @output = File.new(nil_filename_or_has_puts_string, 'wt')
      elsif nil_filename_or_has_puts_string.respond_to?(:puts)
        @output = nil_filename_or_has_puts_string
      else
        raise ArgumentError, 'Include2Ignore::Ignore::initialize: Not nil, string, nor puts in argument'
      end
      @output.puts(config.header) if config.header
      @puts_include = func(config.keep)
      @puts_exclude = func(config.drop)
    end

    def add_include(line)
      @puts_include.call(line)
    end

    def add_exclude(line)
      @puts_exclude.call(line)
    end

    def close
      @output.close if @output.respond_to?(:close)
    end

    private

    def func(prefix)
      return ->(line) {} unless prefix.is_a?(String)
      return ->(line) { @output.puts(line) } if prefix.empty?
      ->(line) { @output.puts("#{prefix}#{line}") }
    end
  end

  # Helper for Classified.
  class Level
    attr_reader :level, :children, :kind, :name, :included, :undecided, :excluded

    def initialize(level, path_parts, is_directory)
      @level = level
      @children = {}
      @kind = nil
      @name = Level.decided_name(path_parts[0..level], (path_parts.size == level + 1) ? is_directory : true)
      @included = 0
      @undecided = 0
      @excluded = 0
    end

    def add(path_parts, exclude, is_directory)
      if path_parts.size == @level + 1
        @kind = exclude
        return
      end
      child = @children[path_parts[@level + 1]]
      if child.nil?
        child = Level.new(@level + 1, path_parts, is_directory)
        @children[path_parts[@level + 1]] = child
      end
      child.add(path_parts, exclude, is_directory)
    end

    def self.decided_name(path_parts, is_directory)
      parts = [ '' ].concat(path_parts)
      parts.push('') if is_directory
      File.join(parts)
    end

    def counts
      @included = 0
      @undecided = 0
      @excluded = 0

      case @kind
      when true then @excluded = 1
      when false then @included = 1
      else
        @undecided = 1 if @children.empty?
      end
      @children.each_value do |child|
        inc, und, ex = child.counts
        @included += inc
        @undecided += und
        @excluded += ex
      end
      [ @included, @undecided, @excluded ]
    end

    def exclude_undecided
      return unless @kind.nil?
      counts if @included.zero? && @undecided.zero? && @excluded.zero?
      if @undecided.positive? && @included.zero?
        # Anything explicitly excluded under this is covered.
        @kind = true
        @children.clear
      else
        @children.each_value(&:exclude_undecided)
      end
    end

    def output(saver)
      unless @kind.nil?
        @kind ? saver.add_exclude(@name) : saver.add_include(@name)
      end
      @children.keys.sort!.each do |key|
        @children[key].output(saver)
      end
    end
  end

  # Stores decisions for all encountered files.
  class Classified
    attr_reader :root

    def initialize
      @root = {}
    end

    def add(path_parts, exclude, is_directory)
      return if path_parts.empty?
      first = path_parts.first
      child = @root[first]
      if child.nil?
        child = Level.new(0, path_parts, is_directory)
        @root[first] = child
      end
      child.add(path_parts, exclude, is_directory)
    end

    def counts
      included = 0
      undecided = 0
      excluded = 0
      @root.each_value do |child|
        inc, und, ex = child.counts
        included += inc
        undecided += und
        excluded += ex
      end
      [ included, undecided, excluded ]
    end

    def pick
      @root.each_value(&:exclude_undecided)
    end

    def output(saver)
      @root.keys.sort!.each do |key|
        @root[key].output(saver)
      end
    end
  end
end
