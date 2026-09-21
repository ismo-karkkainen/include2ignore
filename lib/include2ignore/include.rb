# frozen_string_literal: true

# Copyright © 2026 Ismo Kärkkäinen
# Licensed under Universal Permissive License. See LICENSE.txt.

module Include2Ignore
  # Code related to reading and processing the include file, and comparing with file names.
  module Include
    RULES = [
      [ '\\', :any, :skip, '\\ escapes the meaning of the next character, except newline.' ].freeze,
      [ '\\', :first, :include ].freeze,
      [ '#', :first, :comment, '# starting a line makes the line a comment.' ].freeze,
      [ '!', :first, :exclude, '! starting a line makes the line an exclusion pattern' ].freeze,
      [ '*', :any, :any, '* matches any full or partial file or directory name.' ].freeze,
      [ '**', :any, nil, '** separated using "/" matches one or more directory names.' ].freeze,
      [ '/', :any, :end ].freeze
    ].freeze

    FIRSTS = RULES.select { |r| r[1] == :first }.to_h { |r| [ r.first, r[2] ] }.freeze
    ANYS = RULES.select { |r| r[1] == :any && !r[2].nil? }.to_h { |r| [ r.first, r[2] ] }.freeze

    FILE = :file
    DIR = :dir

    ANY_ONE = Regexp.new('^.*$')

    def self.doc
      <<EOF
Include file is one pattern per line. Special characters:
#{RULES.select { |r| r.last.is_a?(String) }.map { |r| "- #{r.last}\n" }.join}
Last matching rule decides whether file is included or ignored.
EOF
    end

    # Holds all rules and checks if path is to be excluded.
    class Classifier
      attr_reader :rules

      def initialize
        @rules = []
      end

      # Add only relevant rule types. Discards comments and empty rules.
      def add(line)
        r = Rule.new(line)
        @rules.concat(r.anchored) if %i[include exclude].include?(r.kind)
      end

      # Prepares the rules for exclude method.
      def close
        return if @rules.frozen?
        @rules.reverse!
        @rules.freeze
      end

      # Check rule matching against given array of strings, and FILE/DIR category of last element.
      def exclude(path_parts, category)
        @rules.each do |r|
          return r.exclude if r.match?(path_parts, category)
        end
        nil # Caller needs to decide.
      end
    end

    # Helper class for one part of the filename. Used during rule reading.
    class Element
      FILEDIR = :filedir

      attr_reader :items, :re, :raw
      attr_accessor :category

      def initialize
        @items = []
        @category = FILEDIR
        @raw = []
      end

      def push(char)
        raise StandardError, "Include2Ignore::Include::Element::push called after close: #{char}" if @items.nil?
        @raw.push(char)
        item = char
        if @items.last == :skip
          @items.pop
        elsif ANYS.key?(item)
          item = ANYS[item]
        end
        if item == :end
          # Explicit end flags this as directory name.
          @category = DIR unless @items.empty?
          close
        else
          @items.push(item)
        end
        item
      end

      # Sets category and performs checks and rule optimizations.
      def close
        return if @items.nil?
        # We never get comments here since Rule detects them and skips the line.
        if @items.last == :skip # Backslash was last character. No multi-line patterns.
          Include2Ignore::Warnings.warn('Ends with \\')
          @items.pop
        end
        if @items.empty?
          @re = :empty
          Include2Ignore::Warnings.explain("#{@raw.join} = Root or empty.")
        elsif @items.size == 1 && @items.first == :any
          @re = ANY_ONE
          Include2Ignore::Warnings.explain("#{@raw.join} = One directory or file.")
        elsif @items.size == 2 && @items.first == :any && @items.last == :any
          # ** with nothing else.
          @re = :anydirs
          Include2Ignore::Warnings.explain("#{@raw.join} = One or more directories.")
        else
          previous = nil
          dropped = false
          @items.delete_if do |item|
            drop = previous == :any && item == :any
            previous = item
            dropped = true if drop
            drop
          end
          Include2Ignore::Warnings.warn('Had consecutive "*" but was not only "**".') if dropped
          Include2Ignore::Warnings.explain('Starts with whitespace.') if @items.first.is_a?(String) && @items.first.lstrip != @items.first
          Include2Ignore::Warnings.explain('Ends with whitespace.') if @items.last.is_a?(String) && @items.last.rstrip != @items.last
          fixeds = []
          @items.each do |item|
            if item == :any
              fixeds.push(item)
            else
              fixeds.push([]) if fixeds.empty? || !fixeds.last.is_a?(Array)
              fixeds.last.push(item)
            end
          end
          parts = fixeds.map do |chars|
            if chars.is_a?(Array)
              Regexp.escape(chars.join)
            else
              '.*'
            end
          end
          expr = "^#{parts.join}$"
          @re = Regexp.new(expr)
          Include2Ignore::Warnings.explain("#{@raw.join} = Regular expression: #{expr}")
        end
        @items = nil
      end
    end

    # Class for rule used to include or exclude as needed. Used during rule reading.
    class Rule
      attr_reader :kind, :elements

      def initialize(line)
        @kind = :include
        @elements = []
        if line.empty?
          @kind = :comment
        elsif FIRSTS.key?(line[0])
          @kind = FIRSTS[line[0]]
          line = line[1..]
        end
        return if @kind == :comment
        line.each_char do |char|
          @elements.push(Element.new) if @elements.empty? || @elements.last.items.nil?
          @elements.last.push(char)
        end
        @elements.last.close
        # Closed element at root without anything becomes anchor to root.
        # Only last element can be file so ensure categories are DIRs, but keep last.
        if @elements.size > 1
          last = @elements.last.category
          @elements.each { |e| e.category = DIR }
          @elements.last.category = last
        end
        @first_anydirs = @elements.index { |e| e.re == :anydirs } || @elements.size
        @elements.freeze
      end

      # Turns elements to arrays of processed elements and FILEDIR is turned
      # to duplicate arrys with last elemnt category different.
      def processed_elements
        out = []
        if @elements.last.category == Element::FILEDIR
          # Split to two rules so that later processing can deal with FILE or DIR.
          out.push(@elements.map { |e| ProcessedElement.new(e.re, e.category == Element::FILEDIR ? FILE : DIR) })
          out.push(@elements.map { |e| ProcessedElement.new(e.re, DIR) })
        else
          out.push(@elements.map { |e| ProcessedElement.new(e.re, e.category) })
        end
        out
      end

      # Returns andchored rules, multiple when needed, with processed elements.
      def anchored
        procd = processed_elements
        if @elements.first.re == :empty
          # No need for the first empty element due to starting "/" since everything anchored from now on.
          procd.map { |p| AnchoredRule.new(p[1..], @kind == :exclude) }
        else
          # Rule "foo" is like "/foo" and "/**/foo" in shorter notation.
          [].concat(
            procd.map { |p| AnchoredRule.new(p, @kind == :exclude) },
            procd.map { |p| AnchoredRule.new([ ProcessedElement.new(:anydirs, DIR) ].concat(p), @kind == :exclude) }
          )
        end
      end
    end

    # Contains fixed data for matching.
    class ProcessedElement
      attr_reader :category
      attr_accessor :re

      def initialize(regexp_or_type, category)
        raise ArgumentError, "Include2Ignore::Include::ProcessedElement::initialize category not allowed: #{category}" unless [DIR, FILE].include?(category)
        raise ArgumentError, "Include2Ignore::Include::ProcessedElement::initialize mismatch: #{regexp_or_type} and #{category}" if regexp_or_type == :anydirs && category != DIR
        @re = regexp_or_type
        @category = category
      end

      def to_s
        "#{@re}:#{@category}"
      end

      def match?(str, category)
        case category
        when FILE
          return false unless @category == FILE
        when DIR
          return false unless @category == DIR
          return true if @re == :anydirs
        else
          raise ArgumentError, 'Include2Ignore::Include::ProcessedElement::match? category not FILE or DIR'
        end
        return true if str.empty? && @re == :empty
        @re.match?(str)
      end
    end

    # Rule that contains full path from the base directory. Used in actual matching.
    class AnchoredRule
      attr_reader :elements, :first_anydirs, :exclude

      def initialize(processed_elements, exclude)
        @elements = optimize(processed_elements)
        @first_anydirs = @elements.index { |e| e.re == :anydirs } || @elements.size
        @exclude = exclude
      end

      def optimize(elements)
        opt = []
        elements.each do |element|
          next if element.re == :empty
          unless opt.empty? || element.category != DIR
            prev = opt.last
            if prev.re == :anydirs
              if element.re == :anydirs
                # .../**/** is same as .../*/**
                prev.re = ANY_ONE
              elsif element.re.object_id.equal?(ANY_ONE.object_id) # Only symbol was tested.
                # For directories, .../**/*/... equals .../*/**/... pattern.
                opt[-1] = element
                element = prev
              end
            end
          end
          opt.push(element)
        end
        opt
      end

      def to_s
        "#{@exclude ? ' ' : '!'}#{@elements.join(' :: ')}"
      end

      def matching_element_indexes(part, category, skip_non_anydirs)
        indexes = []
        ([ skip_non_anydirs, @first_anydirs ].min...@elements.size).each do |idx|
          element = @elements[idx]
          indexes.push(idx) if element.match?(part, category)
        end
        indexes
      end

      def search(index_arrays, array_index, position_index)
        if array_index == index_arrays.size
          # Last key is known to match last item, so if that were tested, it would pass.
          return position_index == @elements.size - 1
        end
        if @elements[position_index].re == :anydirs
          # :anydir absorbs current key and moves to next position.
          return true if search(index_arrays, array_index + 1, position_index + 1)
          # :anydir absorbs current key and stays for more.
          search(index_arrays, array_index + 1, position_index)
        else
          # Only current item to match with.
          return false if index_arrays[array_index].index(position_index).nil?
          search(index_arrays, array_index + 1, position_index + 1)
        end
      end

      def match?(path_parts, category)
        # Anchored to base directory.
        slack = path_parts.size - @elements.size
        return false if slack.negative? # Path too short.
        return false if slack.positive? && @first_anydirs == @elements.size # Path too long.
        # Last key must match last item.
        return false unless @elements.last.match?(path_parts.last, category)
        # First key must match first item.
        return false unless @elements.first.match?(path_parts.first, path_parts.size == 1 ? category : DIR)
        return true if path_parts.size <= 2 # Tested all already.
        # Form arrays of possible match indexes for search. Omit first and last.
        index_arrays = []
        (1...(path_parts.size - 1)).each do |idx|
          part = path_parts[idx]
          idxs = matching_element_indexes(part, DIR, idx)
          return false if idxs.empty?
          index_arrays.push(idxs)
        end
        search(index_arrays, 0, @elements.first.re == :anydirs ? 0 : 1)
      end
    end
  end
end
