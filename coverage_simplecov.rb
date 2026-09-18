# frozen_string_literal: true

# Copyright 2025 Ismo Kärkkäinen
# Licensed under Universal Permissive License. See LICENSE.txt.

require 'simplecov'
require 'simplecov-console'
SimpleCov.start do
  SimpleCov.formatter = SimpleCov::Formatter::Console
  SimpleCov.add_filter 'test'
end
SimpleCov::Formatter::Console.sort = 'path'
SimpleCov::Formatter::Console.output_style = 'block'
SimpleCov::Formatter::Console.max_rows = nil
SimpleCov::Formatter::Console.show_covered = true
