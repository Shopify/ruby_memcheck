# frozen_string_literal: true

require "ruby_memcheck/shared_test_task_reporter_tests"

module RubyMemcheck
  class RubyRunnerTest < Minitest::Test
    include SharedTestTaskReporterTests

    def setup
      @output_io = StringIO.new
      build_configuration
    end

    private

    def run_with_memcheck(code, raise_on_failure: true, spawn_opts: {})
      script = Tempfile.new
      script.write(<<~RUBY)
        require "ruby_memcheck_c_test_one"
        require "ruby_memcheck_c_test_two"
        #{code}
      RUBY
      script.flush

      exit_code = @test_task.run(
        "-I#{File.join(__dir__, "ext")}",
        script.path,
        **spawn_opts,
      )

      if raise_on_failure && exit_code != 0
        raise "Command failed with status (#{exit_code})"
      end

      exit_code == 0
    end

    def build_test_task
      @test_task = RubyMemcheck::RubyRunner.new(@configuration)
    end
  end
end
