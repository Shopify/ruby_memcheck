# frozen_string_literal: true

module RubyMemcheck
  class TestTask < Rake::TestTask
    include TestTaskReporter

    attr_reader :configuration

    def initialize(*args)
      @configuration =
        if !args.empty? && args[0].is_a?(Configuration)
          args.shift
        else
          RubyMemcheck.default_configuration
        end

      super
    end

    def ruby(*args, **options, &block)
      args.unshift("-r" + File.expand_path(File.join(__dir__, "test_helper.rb")))
      command = configuration.command(args)
      sh(command, **options) do |ok, res|
        report_valgrind_errors

        yield ok, res if block_given?
      end
    end
  end
end
