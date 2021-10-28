# frozen_string_literal: true

require "test_helper"

module RubyMemcheck
  module SharedTestTaskReporterTests
    def test_succeeds_when_there_is_no_memory_leak
      ok = run_with_memcheck(<<~RUBY)
        RubyMemcheck::CTest.new.no_memory_leak
      RUBY

      assert(ok)
      assert_empty(@test_task.errors)
      assert_empty(@output_io.string)
    end

    def test_reports_memory_leak
      assert_raises(RubyMemcheck::TestTask::VALGRIND_REPORT_MSG) do
        run_with_memcheck(<<~RUBY)
          RubyMemcheck::CTest.new.memory_leak
        RUBY
      end

      assert_equal(1, @test_task.errors.length)

      output = @output_io.string
      refute_empty(output)
      assert_match(/^100 bytes in 1 blocks are definitely lost in loss record/, output)
      assert_match(/^ \*memory_leak \(ruby_memcheck_c_test\.c:\d+\)$/, output)
    end

    def test_reports_use_after_free
      assert_raises(RubyMemcheck::TestTask::VALGRIND_REPORT_MSG) do
        run_with_memcheck(<<~RUBY)
          RubyMemcheck::CTest.new.use_after_free
        RUBY
      end

      assert_equal(1, @test_task.errors.length)

      output = @output_io.string
      refute_empty(output)
      assert_match(/^Invalid write of size 1$/, output)
      assert_match(/^ \*use_after_free \(ruby_memcheck_c_test\.c:\d+\)$/, output)
    end

    # Potential improvement: support uninitialized values
    def test_does_not_report_uninitialized_value
      run_with_memcheck(<<~RUBY)
        RubyMemcheck::CTest.new.uninitialized_value
      RUBY

      assert_equal(0, @test_task.errors.length)
      assert_empty(@test_task.errors)
      assert_empty(@output_io.string)
    end

    def test_call_into_ruby_mem_leak_does_not_report
      ok = run_with_memcheck(<<~RUBY)
        RubyMemcheck::CTest.new.call_into_ruby_mem_leak
      RUBY

      assert(ok)
      assert_empty(@test_task.errors)
      assert_empty(@output_io.string)
    end

    def test_call_into_ruby_mem_leak_reports_when_not_skipped
      build_configuration(skipped_ruby_functions: [])

      assert_raises(RubyMemcheck::TestTask::VALGRIND_REPORT_MSG) do
        run_with_memcheck(<<~RUBY)
          RubyMemcheck::CTest.new.call_into_ruby_mem_leak
        RUBY
      end

      assert_operator(@test_task.errors.length, :>=, 1)
    end

    def test_suppressions
      build_configuration(valgrind_suppressions_dir: File.join(__dir__, "suppressions"))

      ok = run_with_memcheck(<<~RUBY)
        RubyMemcheck::CTest.new.memory_leak
      RUBY

      assert(ok)
      assert_empty(@test_task.errors)
      assert_empty(@output_io.string)
    end

    def test_generation_of_suppressions
      valgrind_options = RubyMemcheck::Configuration::DEFAULT_VALGRIND_OPTIONS.dup
      valgrind_options << "--gen-suppressions=all"
      build_configuration(valgrind_options: valgrind_options)

      assert_raises(RubyMemcheck::TestTask::VALGRIND_REPORT_MSG) do
        run_with_memcheck(<<~RUBY)
          RubyMemcheck::CTest.new.memory_leak
        RUBY
      end

      assert_equal(1, @test_task.errors.length)

      output = @output_io.string
      refute_empty(output)
      assert_match(/^100 bytes in 1 blocks are definitely lost in loss record/, output)
      assert_match(/^ \*memory_leak \(ruby_memcheck_c_test\.c:\d+\)$/, output)
      assert_match(/^  insert_a_suppression_name_here/, output)
      assert_match(/^  Memcheck:Leak/, output)
      assert_match(/^  fun:allocate_memory_leak/, output)
    end

    def test_follows_forked_children
      assert_raises(RubyMemcheck::TestTask::VALGRIND_REPORT_MSG) do
        run_with_memcheck(<<~RUBY)
          pid = Process.fork do
            RubyMemcheck::CTest.new.memory_leak
          end

          Process.wait(pid)
        RUBY
      end

      assert_equal(1, @test_task.errors.length)

      output = @output_io.string
      refute_empty(output)
      assert_match(/^100 bytes in 1 blocks are definitely lost in loss record/, output)
      assert_match(/^ \*memory_leak \(ruby_memcheck_c_test\.c:\d+\)$/, output)
    end

    def test_reports_multiple_errors
      assert_raises(RubyMemcheck::TestTask::VALGRIND_REPORT_MSG) do
        run_with_memcheck(<<~RUBY)
          RubyMemcheck::CTest.new.memory_leak
          RubyMemcheck::CTest.new.use_after_free
        RUBY
      end

      assert_equal(2, @test_task.errors.length)

      output = @output_io.string
      refute_empty(output)
      assert_match(/^100 bytes in 1 blocks are definitely lost in loss record/, output)
      assert_match(/^ \*memory_leak \(ruby_memcheck_c_test\.c:\d+\)$/, output)
      assert_match(/^Invalid write of size 1$/, output)
      assert_match(/^ \*use_after_free \(ruby_memcheck_c_test\.c:\d+\)$/, output)
    end

    def test_ruby_failure_without_errors
      ok = run_with_memcheck(<<~RUBY, raise_on_failure: false, spawn_opts: { out: "/dev/null", err: "/dev/null" })
        foobar
      RUBY

      refute(ok)
      assert_empty(@test_task.errors)
      assert_empty(@output_io.string)
    end

    def test_ruby_failure_with_errors
      assert_raises(RubyMemcheck::TestTask::VALGRIND_REPORT_MSG) do
        run_with_memcheck(<<~RUBY, raise_on_failure: false, spawn_opts: { out: "/dev/null", err: "/dev/null" })
          RubyMemcheck::CTest.new.memory_leak
          raise
        RUBY
      end

      assert_equal(1, @test_task.errors.length)

      output = @output_io.string
      refute_empty(output)
      assert_match(/^100 bytes in 1 blocks are definitely lost in loss record/, output)
      assert_match(/^ \*memory_leak \(ruby_memcheck_c_test\.c:\d+\)$/, output)
    end

    private

    def run_with_memcheck(code, raise_on_failure: true, spawn_opts: {})
      raise NotImplementedError
    end

    def build_configuration(
      binary_name: "ruby_memcheck_c_test",
      output_io: @output_io,
      **options
    )
      @configuration = Configuration.new(
        binary_name: "ruby_memcheck_c_test",
        output_io: @output_io,
        **options
      )
      build_test_task
    end

    def build_test_task
      raise NotImplementedError
    end
  end
end
