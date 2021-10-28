# frozen_string_literal: true

require "ruby_memcheck/shared_test_task_reporter_tests"

module RubyMemcheck
  class TestTaskTest < Minitest::Test
    include SharedTestTaskReporterTests

    def setup
      Rake::FileUtilsExt.verbose_flag = false

      @output_io = StringIO.new
      build_configuration
    end

    private

    def run_with_memcheck(code, raise_on_failure: true, spawn_opts: {})
      script = Tempfile.new
      script.write(<<~RUBY)
        require "ruby_memcheck_c_test"
        #{code}
      RUBY
      script.flush

      ok = nil

      @test_task.ruby(
        "-I#{File.join(__dir__, "ext")}",
        script.path,
        **spawn_opts
      ) do |ok_val, status|
        ok = ok_val

        if raise_on_failure && !ok
          raise "Command failed with status (#{status.exitstatus})"
        end
      end

      ok
    end

    def build_test_task
      @test_task = RubyMemcheck::TestTask.new(@configuration)
    end
  end
end
