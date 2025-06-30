#!/usr/bin/env crystal

require "./topia"

# CLI Binary Entry Point for Topia
#
# This file provides the main entry point for the Topia CLI tool.
# Users can compile this to create a standalone topia binary:
#   crystal build src/cli.cr -o topia
#
# Usage examples:
#   ./topia build
#   ./topia -l
#   ./topia -p build test
#   ./topia --help

begin
  # Run the CLI with command line arguments
  Topia.cli(ARGV)
rescue ex : Topia::Error
  puts "ERROR: #{ex.message}".colorize(:red)
  exit(1)
rescue ex
  puts "FATAL ERROR: #{ex.message}".colorize(:red)
  puts "Use --debug for more information" unless ARGV.includes?("--debug")
  exit(1)
end
