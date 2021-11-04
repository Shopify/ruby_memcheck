# frozen_string_literal: true

module RubyMemcheck
  class Configuration
    DEFAULT_VALGRIND = "valgrind"
    DEFAULT_VALGRIND_OPTIONS = [
      "--num-callers=50",
      "--error-limit=no",
      "--trace-children=yes",
      "--undef-value-errors=no",
      "--leak-check=full",
      "--show-leak-kinds=definite",
    ].freeze
    DEFAULT_VALGRIND_SUPPRESSIONS_DIR = "suppressions"
    DEFAULT_SKIPPED_RUBY_FUNCTIONS = [
      /\Aeval_string_with_cref\z/,
      /\Arb_add_method_cfunc\z/,
      /\Arb_check_funcall/,
      /\Arb_class_boot\z/, # Called for all the different ways to create a Class
      /\Arb_enc_raise\z/,
      /\Arb_exc_raise\z/,
      /\Arb_extend_object\z/,
      /\Arb_funcall/,
      /\Arb_intern/,
      /\Arb_ivar_set\z/,
      /\Arb_module_new\z/,
      /\Arb_raise\z/,
      /\Arb_rescue/,
      /\Arb_respond_to\z/,
      /\Arb_thread_create\z/, # Threads are relased to a cache, so they may be reported as a leak
      /\Arb_yield/,
    ].freeze

    attr_reader :binary_name, :ruby, :valgrind, :valgrind_options, :valgrind_suppressions_dir,
      :valgrind_generate_suppressions, :skipped_ruby_functions, :valgrind_xml_dir, :output_io
    alias_method :valgrind_generate_suppressions?, :valgrind_generate_suppressions

    def initialize(
      binary_name:,
      ruby: FileUtils::RUBY,
      valgrind: DEFAULT_VALGRIND,
      valgrind_options: DEFAULT_VALGRIND_OPTIONS,
      valgrind_suppressions_dir: DEFAULT_VALGRIND_SUPPRESSIONS_DIR,
      valgrind_generate_suppressions: false,
      skipped_ruby_functions: DEFAULT_SKIPPED_RUBY_FUNCTIONS,
      valgrind_xml_dir: Dir.mktmpdir,
      output_io: $stderr
    )
      @binary_name = binary_name
      @ruby = ruby
      @valgrind = valgrind
      @valgrind_options = valgrind_options
      @valgrind_suppressions_dir = File.expand_path(valgrind_suppressions_dir)
      @valgrind_generate_suppressions = valgrind_generate_suppressions
      @skipped_ruby_functions = skipped_ruby_functions
      @output_io = output_io

      if valgrind_xml_dir
        valgrind_xml_dir = File.expand_path(valgrind_xml_dir)
        FileUtils.mkdir_p(valgrind_xml_dir)
        @valgrind_xml_dir = valgrind_xml_dir
        @valgrind_options += [
          "--xml=yes",
          # %p will be replaced with the PID
          # This prevents forking and shelling out from generating a corrupted XML
          # See --log-file from https://valgrind.org/docs/manual/manual-core.html
          "--xml-file=#{File.join(valgrind_xml_dir, "%p.out")}",
        ]
      end
    end

    def command(*args)
      [
        # On some Rubies, not setting the stack size to be ulimited causes
        # Valgrind to report the following error:
        #   Invalid write of size 1
        #     reserve_stack (thread_pthread.c:845)
        #     ruby_init_stack (thread_pthread.c:871)
        #     main (main.c:48)
        "ulimit -s unlimited && ",
        valgrind,
        valgrind_options,
        get_valgrind_suppression_files(valgrind_suppressions_dir).map { |f| "--suppressions=#{f}" },
        valgrind_generate_suppressions ? "--gen-suppressions=all" : "",
        ruby,
        args,
      ].flatten.join(" ")
    end

    private

    def get_valgrind_suppression_files(dir)
      full_ruby_version = "#{RUBY_ENGINE}-#{RUBY_VERSION}.#{RUBY_PATCHLEVEL}"
      versions = [full_ruby_version]
      (0..3).reverse_each { |i| versions << full_ruby_version.split(".")[0, i].join(".") }
      versions << RUBY_ENGINE

      versions.map do |version|
        Dir[File.join(dir, "#{binary_name}_#{version}.supp")]
      end.flatten
    end
  end
end
