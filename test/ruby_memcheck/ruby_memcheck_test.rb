# frozen_string_literal: true

require "ruby_memcheck/shared_test_task_reporter_tests"

module RubyMemcheck
  class RubyMemcheckTest < Minitest::Test
    include SharedTestTaskReporterTests

    def setup
      Rake::FileUtilsExt.verbose_flag = false

      @output_io = StringIO.new
      build_configuration
    end

    private

    def run_with_memcheck(code, raise_on_failure: true, spawn_opts: {})
      script = Tempfile.new
      script.write("require 'ruby_memcheck_c_test'\n#{code}")
      script.flush

      ok = nil
      status = nil

      @test_task.ruby(
        "-I#{File.join(__dir__, "ext")}",
        script.path,
        **spawn_opts
      ) do |ok_val, status_val|
        ok = ok_val
        status = status_val

        if raise_on_failure && !ok
          raise "Command failed with status (#{status.exitstatus})"
        end
      end

      [ok, status]
    end
  end
end
