# frozen_string_literal: true

module RubyMemcheck
  class Configuration
    DEFAULT_VALGRIND = "valgrind"
    DEFAULT_VALGRIND_OPTIONS = [
      "--num-callers=50",
      "--error-limit=no",
      "--undef-value-errors=no",
      "--leak-check=full",
      "--show-leak-kinds=definite",
    ].freeze
    DEFAULT_SKIPPED_RUBY_FUNCTIONS = [
      /\Arb_check_funcall/,
      /\Arb_enc_raise\z/,
      /\Arb_exc_raise\z/,
      /\Arb_funcall/,
      /\Arb_intern/,
      /\Arb_ivar_set\z/,
      /\Arb_raise\z/,
      /\Arb_rescue/,
      /\Arb_respond_to\z/,
      /\Arb_yield/,
    ].freeze

    attr_reader :binary_name, :ruby, :valgrind_options, :valgrind,
      :skipped_ruby_functions, :valgrind_xml_file, :output_io

    def initialize(
      binary_name:,
      ruby: FileUtils::RUBY,
      valgrind: DEFAULT_VALGRIND,
      valgrind_options: DEFAULT_VALGRIND_OPTIONS,
      skipped_ruby_functions: DEFAULT_SKIPPED_RUBY_FUNCTIONS,
      valgrind_xml_file: Tempfile.new,
      output_io: $stderr
    )
      @binary_name = binary_name
      @ruby = ruby
      @valgrind = valgrind
      @valgrind_options = valgrind_options
      @skipped_ruby_functions = skipped_ruby_functions
      @output_io = output_io

      if valgrind_xml_file
        @valgrind_xml_file = valgrind_xml_file
        @valgrind_options += [
          "--xml=yes",
          "--xml-file=#{valgrind_xml_file.path}",
        ]
      end
    end

    def command(*args)
      "#{valgrind} #{valgrind_options.join(" ")} #{ruby} #{args.join(" ")}"
    end

    def skip_stack?(stack)
      stack.frames.each do |frame|
        fn = frame.fn

        if frame_in_ruby?(frame) # in ruby
          # Skip this stack because it was called from Ruby
          return true if skipped_ruby_functions.any? { |r| r.match?(fn) }
        elsif frame_in_binary?(frame) # in binary
          # Skip the Init function
          return true if fn == "Init_#{binary_name}"

          return false
        end
      end

      return true
    end

    def frame_in_ruby?(frame)
      frame.obj == ruby ||
        # Hack to fix Ruby built with --enabled-shared
        File.basename(frame.obj) == "libruby.so.#{RUBY_VERSION}"
    end

    def frame_in_binary?(frame)
      if frame.obj
        File.basename(frame.obj, ".*") == binary_name
      else
        false
      end
    end
  end
end
