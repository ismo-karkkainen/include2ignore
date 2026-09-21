# frozen_string_literal: true

require_relative 'lib/include2ignore/version'
require 'simpleidn'
require 'rake'

Gem::Specification.new do |s|
  s.name = Include2Ignore::NAME
  s.version = Include2Ignore::VERSION
  s.summary = 'Reads include file, finds files under directory, and outputs ignore file.'
  s.description = <<EOF
Takes a list of file names or patterns, finds all files that do not match any
of them, or only match exclude patterns in the input file, and outputs them.
If directory contains no files that are included, outputs the directory
instead of individual files.
EOF
  s.authors = [ 'Ismo Kärkkäinen' ]
  s.email = 'ismokarkkainen@icloud.com'
  s.files = FileList[ 'lib/include2ignore.rb', 'lib/include2ignore/*.rb', 'LICENSE.txt' ].to_a
  s.executables << 'include2ignore'
  s.homepage = "https://#{SimpleIDN.to_ascii('ismo-kärkkäinen.fi')}/#{Include2Ignore::NAME}/index.html"
  s.license = 'UPL-1.0'
  s.required_ruby_version = '>= 3.3.11'
  s.metadata = { 'rubygems_mfa_required' => 'true' }
end
