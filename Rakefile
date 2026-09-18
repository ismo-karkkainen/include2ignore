# frozen_string_literal: true

# Copyright 2026 Ismo Kärkkäinen
# Licensed under Universal Permissive License. See LICENSE.txt.

require 'rubocop/rake_task'

task default: [:test]

desc 'Clean.'
task :clean do
  sh 'rm -f include2ignore-*.gem'
end

desc 'Build gem.'
task gem: [:clean] do
  sh 'gem build include2ignore.gemspec'
end

desc 'Build and install gem.'
task install: [:gem] do
  sh 'gem install include2ignore-*.gem'
end

desc 'Uninstall gem.'
task :uninstall do
  sh 'gem uninstall --executables include2ignore'
end

desc 'Test.'
task :test do
  require_relative 'coverage_simplecov'
  require 'test/unit'
  Test::Unit::AutoRunner.run(true)
end

desc 'Lint using Rubocop'
RuboCop::RakeTask.new(:lint) do |t|
  t.patterns = [ 'bin', 'lib', 'include2ignore.gemspec' ]
end
