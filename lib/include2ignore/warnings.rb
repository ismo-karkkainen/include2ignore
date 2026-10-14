# frozen_string_literal: true

# Copyright © 2026 Ismo Kärkkäinen
# Licensed under Universal Permissive License. See LICENSE.txt.

require 'singleton'


module Include2Ignore
  # Allows higher-level code to set context, lower-level to display warnings.
  # Usage:
  # At top level where verbosity is set: Include2Ignore::Warnings.output_explanations(verbosity)
  # At level where location is known: Include2Ignore::Warnings.where(description)
  # At lower level where warnings or other are found:
  # Output always: Include2Ignore::Warnings.warn(message)
  # Output only when verbose: Include2Ignore::Warnings.explain(message)
  class Warnings
    include Singleton

    attr_reader :context
    attr_accessor :verbose, :output

    def self.output(nil_or_has_puts_string)
      Warnings.instance.output = nil_or_has_puts_string
    end

    def where(location)
      @context = location
    end

    def self.where(location)
      Warnings.instance.where(location)
    end

    def warn(message, omit_context = false)
      @output = $stderr if @output.nil?
      if omit_context
        @output.puts(message)
      else
        @output.puts(@context) unless @context.nil?
        @context = nil
        @output.puts("  #{message}")
      end
    end

    def self.warn(message, omit_context = false)
      Warnings.instance.warn(message, omit_context)
    end

    def self.output_explanations(verbose)
      Warnings.instance.verbose = verbose
    end

    def explain(message)
      warn(message) if @verbose
    end

    def self.explain(message)
      Warnings.instance.explain(message)
    end
  end
end
