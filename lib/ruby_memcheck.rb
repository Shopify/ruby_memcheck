require "tempfile"
require "nokogiri"
require "rake/testtask"

require "ruby_memcheck/configuration"
require "ruby_memcheck/frame"
require "ruby_memcheck/stack"
require "ruby_memcheck/test_task"
require "ruby_memcheck/valgrind_error"
require "ruby_memcheck/version"

module RubyMemcheck
  class << self
    def config(**opts)
      @default_configuration = Configuration.new(**opts)
    end

    def default_configuration
      unless @default_configuration
        raise "RubyMemcheck is not configured with a default configuration. "\
              "Please run RubyMemcheck.config before using it."
      end
      @default_configuration
    end
  end
end
