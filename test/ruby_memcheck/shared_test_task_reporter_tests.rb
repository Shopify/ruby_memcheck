# frozen_string_literal: true

require "test_helper"

module RubyMemcheck
  module SharedTestTaskReporterTests
    def test_succeeds_when_there_is_no_memory_leak
      ok = run_with_memcheck(<<~RUBY)
        RubyMemcheck::CTestOne.new.no_memory_leak
      RUBY

      assert(ok)
      assert_empty(@test_task.reporter.errors)
      assert_empty(@output_io.string)
    end

    def test_reports_memory_leak
      error = assert_raises do
        run_with_memcheck(<<~RUBY)
          RubyMemcheck::CTestOne.new.memory_leak
        RUBY
      end
      assert_equal(RubyMemcheck::TestTaskReporter::VALGRIND_REPORT_MSG, error.message)

      output = @output_io.string

      assert_equal(1, @test_task.reporter.errors.length, output)

      refute_empty(output)
      assert_match(/^100 bytes in 1 blocks are definitely lost in loss record/, output)
      assert_match(/^ \*c_test_one_memory_leak \(ruby_memcheck_c_test_one\.c:\d+\)$/, output)
    end

    def test_reports_use_after_free
      error = assert_raises do
        run_with_memcheck(<<~RUBY)
          RubyMemcheck::CTestOne.new.use_after_free
        RUBY
      end
      assert_equal(RubyMemcheck::TestTaskReporter::VALGRIND_REPORT_MSG, error.message)

      output = @output_io.string

      assert_equal(1, @test_task.reporter.errors.length, output)

      refute_empty(output)
      assert_match(/^Invalid write of size 1$/, output)
      assert_match(/^ \*c_test_one_use_after_free \(ruby_memcheck_c_test_one\.c:\d+\)$/, output)
    end

    # Potential improvement: support uninitialized values
    def test_does_not_report_uninitialized_value
      run_with_memcheck(<<~RUBY)
        RubyMemcheck::CTestOne.new.uninitialized_value
      RUBY

      assert_equal(0, @test_task.reporter.errors.length, @output_io.string)
      assert_empty(@test_task.reporter.errors)
      assert_empty(@output_io.string)
    end

    def test_call_into_ruby_mem_leak_does_not_report_when_RUBY_FREE_AT_EXIT_is_not_supported
      skip if Configuration::RUBY_FREE_AT_EXIT_SUPPORTED

      ok = run_with_memcheck(<<~RUBY)
        RubyMemcheck::CTestOne.new.call_into_ruby_mem_leak
      RUBY

      assert(ok)
      assert_empty(@test_task.reporter.errors)
      assert_empty(@output_io.string)
    end

    def test_call_into_ruby_mem_leak_not_report_when_RUBY_FREE_AT_EXIT_is_supported
      skip unless Configuration::RUBY_FREE_AT_EXIT_SUPPORTED

      error = assert_raises do
        run_with_memcheck(<<~RUBY)
          RubyMemcheck::CTestOne.new.call_into_ruby_mem_leak
        RUBY
      end
      assert_equal(RubyMemcheck::TestTaskReporter::VALGRIND_REPORT_MSG, error.message)

      output = @output_io.string
      assert_equal(1, @test_task.reporter.errors.length, output)

      refute_empty(output)
      assert_match(/^ \*c_test_one_call_into_ruby_mem_leak \(ruby_memcheck_c_test_one\.c:\d+\)$/, output)
    end

    def test_call_into_ruby_mem_leak_not_report_when_RUBY_FREE_AT_EXIT_is_supported_but_use_only_ruby_free_at_exit_disabled
      skip unless Configuration::RUBY_FREE_AT_EXIT_SUPPORTED

      build_configuration(use_only_ruby_free_at_exit: false)

      ok = run_with_memcheck(<<~RUBY)
        RubyMemcheck::CTestOne.new.call_into_ruby_mem_leak
      RUBY

      assert(ok)
      assert_empty(@test_task.reporter.errors)
      assert_empty(@output_io.string)
    end

    def test_call_into_ruby_mem_leak_reports_when_not_skipped
      build_configuration(skipped_ruby_functions: [])

      error = assert_raises do
        run_with_memcheck(<<~RUBY)
          RubyMemcheck::CTestOne.new.call_into_ruby_mem_leak
        RUBY
      end
      assert_equal(RubyMemcheck::TestTaskReporter::VALGRIND_REPORT_MSG, error.message)

      assert_operator(@test_task.reporter.errors.length, :>=, 1, @output_io.string)
    end

    def test_suppressions
      build_configuration(valgrind_suppressions_dir: File.join(__dir__, "suppressions"))

      ok = run_with_memcheck(<<~RUBY)
        RubyMemcheck::CTestOne.new.memory_leak
      RUBY

      assert(ok)
      assert_empty(@test_task.reporter.errors)
      assert_empty(@output_io.string)
    end

    def test_generation_of_suppressions
      build_configuration(valgrind_generate_suppressions: true)

      error = assert_raises do
        run_with_memcheck(<<~RUBY)
          RubyMemcheck::CTestOne.new.memory_leak
        RUBY
      end
      assert_equal(RubyMemcheck::TestTaskReporter::VALGRIND_REPORT_MSG, error.message)

      output = @output_io.string

      assert_equal(1, @test_task.reporter.errors.length, output)

      refute_empty(output)
      assert_match(/^100 bytes in 1 blocks are definitely lost in loss record/, output)
      assert_match(/^ \*c_test_one_memory_leak \(ruby_memcheck_c_test_one\.c:\d+\)$/, output)
      assert_match(/^  insert_a_suppression_name_here/, output)
      assert_match(/^  Memcheck:Leak/, output)
      assert_match(/^  fun:c_test_one_allocate_memory_leak/, output)
    end

    def test_follows_forked_children
      error = assert_raises do
        run_with_memcheck(<<~RUBY)
          pid = Process.fork do
            RubyMemcheck::CTestOne.new.memory_leak
          end

          Process.wait(pid)
        RUBY
      end
      assert_equal(RubyMemcheck::TestTaskReporter::VALGRIND_REPORT_MSG, error.message)

      output = @output_io.string

      assert_equal(1, @test_task.reporter.errors.length, output)

      refute_empty(output)
      assert_match(/^100 bytes in 1 blocks are definitely lost in loss record/, output)
      assert_match(/^ \*c_test_one_memory_leak \(ruby_memcheck_c_test_one\.c:\d+\)$/, output)
    end

    def test_reports_multiple_errors
      error = assert_raises do
        run_with_memcheck(<<~RUBY)
          RubyMemcheck::CTestOne.new.memory_leak
          RubyMemcheck::CTestOne.new.use_after_free
        RUBY
      end
      assert_equal(RubyMemcheck::TestTaskReporter::VALGRIND_REPORT_MSG, error.message)

      output = @output_io.string

      assert_equal(2, @test_task.reporter.errors.length, output)

      refute_empty(output)
      assert_match(/^100 bytes in 1 blocks are definitely lost in loss record/, output)
      assert_match(/^ \*c_test_one_memory_leak \(ruby_memcheck_c_test_one\.c:\d+\)$/, output)
      assert_match(/^Invalid write of size 1$/, output)
      assert_match(/^ \*c_test_one_use_after_free \(ruby_memcheck_c_test_one\.c:\d+\)$/, output)
    end

    def test_reports_errors_in_all_binaries
      error = assert_raises do
        run_with_memcheck(<<~RUBY)
          RubyMemcheck::CTestOne.new.memory_leak
          RubyMemcheck::CTestTwo.new.memory_leak
        RUBY
      end
      assert_equal(RubyMemcheck::TestTaskReporter::VALGRIND_REPORT_MSG, error.message)

      output = @output_io.string

      assert_equal(2, @test_task.reporter.errors.length, output)

      refute_empty(output)
      assert_match(/^100 bytes in 1 blocks are definitely lost in loss record/, output)
      assert_match(/^ \*c_test_one_memory_leak \(ruby_memcheck_c_test_one\.c:\d+\)$/, output)
      assert_match(/^ \*c_test_two_memory_leak \(ruby_memcheck_c_test_two\.c:\d+\)$/, output)
    end

    def test_can_run_multiple_times
      2.times do
        ok = run_with_memcheck(<<~RUBY)
          RubyMemcheck::CTestOne.new.no_memory_leak
        RUBY
        assert(ok)
      end
    end

    def test_ruby_failure_without_errors
      ok = run_with_memcheck(<<~RUBY, raise_on_failure: false, spawn_opts: { out: "/dev/null", err: "/dev/null" })
        foobar
      RUBY

      refute(ok)
      assert_empty(@test_task.reporter.errors)
      assert_empty(@output_io.string)
    rescue
      $stderr.puts(@test_task.reporter.errors)
      raise
    end

    def test_ruby_failure_with_errors
      error = assert_raises do
        run_with_memcheck(<<~RUBY, raise_on_failure: false, spawn_opts: { out: "/dev/null", err: "/dev/null" })
          RubyMemcheck::CTestOne.new.memory_leak
          raise
        RUBY
      end
      assert_equal(RubyMemcheck::TestTaskReporter::VALGRIND_REPORT_MSG, error.message)

      output = @output_io.string

      assert_equal(1, @test_task.reporter.errors.length, output)

      refute_empty(output)
      assert_match(/^100 bytes in 1 blocks are definitely lost in loss record/, output)
      assert_match(/^ \*c_test_one_memory_leak \(ruby_memcheck_c_test_one\.c:\d+\)$/, output)
    end

    def test_test_helper_is_loaded
      Tempfile.create do |tempfile|
        ok = run_with_memcheck(<<~RUBY)
          File.write(#{tempfile.path.inspect}, $LOADED_FEATURES.join("\n"))
        RUBY

        assert(ok)
        assert_empty(@test_task.reporter.errors)
        assert_includes(tempfile.read, File.expand_path(File.join(__dir__, "../../lib/ruby_memcheck/test_helper.rb")))
      end
    end

    def test_environment_variable_RUBY_MEMCHECK_RUNNING
      Tempfile.create do |tempfile|
        ok = run_with_memcheck(<<~RUBY, raise_on_failure: false)
          File.write(#{tempfile.path.inspect}, ENV["RUBY_MEMCHECK_RUNNING"])
        RUBY

        assert(ok)
        assert_empty(@test_task.reporter.errors)
        assert_includes(tempfile.read, "1")
      end
    end

    def test_environment_variable_RUBY_FREE_AT_EXIT
      Tempfile.create do |tempfile|
        ok = run_with_memcheck(<<~RUBY, raise_on_failure: false)
          File.write(#{tempfile.path.inspect}, ENV["RUBY_FREE_AT_EXIT"])
        RUBY

        assert(ok)
        assert_empty(@test_task.reporter.errors)
        assert_includes(tempfile.read, "1")
      end
    end

    def test_configration_binary_name
      build_configuration(binary_name: "ruby_memcheck_c_test_one")
      error = assert_raises do
        run_with_memcheck(<<~RUBY)
          RubyMemcheck::CTestOne.new.memory_leak
          RubyMemcheck::CTestTwo.new.memory_leak
        RUBY
      end
      assert_equal(RubyMemcheck::TestTaskReporter::VALGRIND_REPORT_MSG, error.message)

      output = @output_io.string

      assert_equal(1, @test_task.reporter.errors.length, output)

      refute_empty(output)
      assert_match(/^100 bytes in 1 blocks are definitely lost in loss record/, output)
      assert_match(/^ \*c_test_one_memory_leak \(ruby_memcheck_c_test_one\.c:\d+\)$/, output)
    end

    def test_configration_invalid_binary_name
      build_configuration(binary_name: "invalid_binary_name")
      error = assert_raises do
        run_with_memcheck(<<~RUBY)
          RubyMemcheck::CTestOne.new.memory_leak
        RUBY
      end
      assert_includes(error.message, "`invalid_binary_name`")
    end

    private

    def run_with_memcheck(code, raise_on_failure: true, spawn_opts: {})
      raise NotImplementedError
    end

    def build_configuration(
      output_io: @output_io,
      **options
    )
      @configuration = Configuration.new(
        output_io: @output_io,
        **options,
      )
      build_test_task
    end

    def build_test_task
      raise NotImplementedError
    end
  end
end
