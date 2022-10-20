# frozen_string_literal: true

require "rspec/core/rake_task"

module RubyMemcheck
  module RSpec
    class RakeTask < ::RSpec::Core::RakeTask
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

      def run_task(verbose)
        error = nil

        begin
          # RSpec::Core::RakeTask#run_task calls Kernel.exit on failure
          super
        rescue SystemExit => e
          error = e
        end

        report_valgrind_errors

        raise error if error
      end

      private

      def spec_command
        # First part of command is Ruby
        args = super.split(" ")[1..]
        args.unshift("-r" + File.expand_path(File.join(__dir__, "../test_helper.rb")))

        configuration.command(args)
      end
    end
  end
end
