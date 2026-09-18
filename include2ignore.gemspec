# frozen_string_literal: true

require_relative 'lib/include2ignore/version'
require 'simpleidn'
require 'rake'

Gem::Specification.new do |s|
  s.name = Include2Ignore::NAME
  s.version = Include2Ignore::VERSION
  s.summary = 'Tool for turning included file list to ignored file list.'
  s.description = <<EOF
Tool for turning a list of files to include to a list of files to ignore,
given the directory for obtaining a list of files in it. Intended for cases
where it is easier to keep a list of files to include, and the ignore file
of the tool does not support ignoring everything and then adding exceptions,
which is the same as passing a list of files and directories to include.
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
