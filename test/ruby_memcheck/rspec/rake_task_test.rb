# frozen_string_literal: true

require "ruby_memcheck"
require "ruby_memcheck/rspec/rake_task"
require "ruby_memcheck/shared_test_task_reporter_tests"

module RubyMemcheck
  module RSpec
    class RakeTaskTest < Minitest::Test
      include SharedTestTaskReporterTests

      def setup
        @output_io = StringIO.new
        build_configuration
      end

      private

      def run_with_memcheck(code, raise_on_failure: true, spawn_opts: {})
        ok = true
        stdout = nil

        Dir.chdir(Dir.mktmpdir) do |dir|
          spec_dir = File.join(dir, "spec")
          Dir.mkdir(spec_dir)

          stdout_log = Tempfile.new("", spec_dir)

          script = Tempfile.new(["", "_spec.rb"], spec_dir)
          script.write(<<~RUBY)
            # Redirect stdout to log file for RSpec output
            $stdout.reopen(File.open("#{stdout_log.path}", "w"))

            $LOAD_PATH.unshift("#{File.join(__dir__, "../ext")}")
            require "ruby_memcheck_c_test_one"
            require "ruby_memcheck_c_test_two"

            RSpec.describe RubyMemcheck do
              it "test" do
                #{code}
              end
            end
          RUBY
          script.flush

          begin
            @test_task.run_task(false)
          rescue SystemExit
            # RSpec::Core::RakeTask#run_task calls Kernel.exit on failure
            ok = false
          end

          # Get the stdout of RSpec
          stdout = File.read(stdout_log.path)

          # Check RSpec test passed
          unless /^1 example, 0 failures$/.match?(stdout)
            ok = false
          end
        end

        if raise_on_failure && !ok
          raise "Command failed. stdout:\n#{stdout}"
        end

        ok
      end

      def build_test_task
        @test_task = RubyMemcheck::RSpec::RakeTask.new(@configuration)
      end
    end
  end
end
