# frozen_string_literal: true

# Copyright © 2026 Ismo Kärkkäinen
# Licensed under Universal Permissive License. See LICENSE.txt.

require_relative 'include'
require_relative 'warnings'


module Include2Ignore
  # Directory tree traversal to find files and decide what to do.
  module Search
    DIR_SYMLINK_HANDLING = %i[reject skip check follow].freeze
    @@dir_symlink_handling = DIR_SYMLINK_HANDLING.last
    def self.dir_symlink_handling
      @@dir_symlink_handling
    end

    def self.dir_symlink_handling=(value)
      raise ArgumentError, "Include2Ignore::Search::dir_symlink_handling: not in #{DIR_SYMLINK_HANDLING.join(', ')}: #{value}" unless DIR_SYMLINK_HANDLING.include?(value)
      @@dir_symlink_handling = value
    end

    FILE_SYMLINK_HANDLING = %i[reject skip check].freeze
    @@file_symlink_handling = FILE_SYMLINK_HANDLING.last
    def self.file_symlink_handling
      @@file_symlink_handling
    end

    def self.file_symlink_handling=(value)
      raise ArgumentError, "Include2Ignore::Search::file_symlink_handling: not in #{FILE_SYMLINK_HANDLING.join(', ')}: #{value}" unless FILE_SYMLINK_HANDLING.include?(value)
      @@file_symlink_handling = value
    end

    def self.doc
      <<EOF
Symbolic link handling:
- reject: Always ignore.
- skip: Do not test, do not follow directory symlinks.
- check: Check against rules but do not follow directory symlinks.
- follow: Check and follow directory symlinks.
EOF
    end

    # Helper class for Traverser.
    class TraversalEntry
      include Comparable

      attr_reader :name, :full_name, :stat, :handle

      def initialize(name, full_name)
        @name = name
        @full_name = full_name
        @stat = File.lstat(full_name)
        if @stat.symlink?
          begin
            @stat = File.stat(full_name)
            if @stat.directory?
              @handle = Search.dir_symlink_handling
              if @handle == :follow
                @full_name = File.realdirpath(full_name)
              end
            else
              @handle = Search.file_symlink_handling
            end
          rescue Errno::ENOENT
            Include2Ignore::Warnings.warn("Symlink broken: #{full_name}")
            @handle = :reject
          rescue Errno::ELOOP
            Include2Ignore::Warnings.warn("Symlink loop: #{full_name}")
            @handle = :reject
          end
        elsif @stat.directory?
          @handle = :follow
          @full_name = File.realdirpath(full_name)
        else
          @handle = :check
        end
      end

      def directory?
        @stat.directory? && @handle == :follow
      end

      def skip?
        @handle == :skip
      end

      def reject?
        @handle == :reject
      end

      def ino
        @stat.ino
      end

      def path_name
        @name.nil? ? @full_name : @name
      end
    end

    def self.traverser(path_parts, skip, &block)
      full_dir = File.join(path_parts.map(&:path_name))
      dir = Dir.new(full_dir)
      dir.each_child.map do |name|
        full_name = File.join(full_dir, name)
        t = TraversalEntry.new(name, full_name)
        next if t.skip? # Should yield something to simplify testing.
        path_parts.push(t)
        # If skip rules explicitly include, then we skip.
        names = path_parts[1..].map(&:name)
        s = skip.exclude(names, t.directory? ? Include2Ignore::Include::DIR : Include2Ignore::Include::FILE)
        if s.nil? || s
          yield(names, t.directory?, t.reject?)
          if t.directory? && path_parts.map(&:ino).index(t.ino) == path_parts.size - 1
            traverser(path_parts, skip, &block)
          end
        end
        path_parts.pop
      end
    end

    def self.traverse(basedir, skip, &)
      Search.traverser([ TraversalEntry.new(nil, basedir) ], skip, &)
    end
  end
end
