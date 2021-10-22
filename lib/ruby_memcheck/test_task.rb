# frozen_string_literal: true

module RubyMemcheck
  class TestTask < Rake::TestTask
    VALGRIND_REPORT_MSG = "Valgrind reported errors (e.g. memory leak or use-after-free)"

    attr_reader :configuration, :errors

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
      command = configuration.command(args)
      sh(command, **options) do |ok, res|
        if configuration.valgrind_xml_file
          parse_valgrind_output
          unless errors.empty?
            output_valgrind_errors
            raise VALGRIND_REPORT_MSG
          end
        end

        yield ok, res if block_given?
      end
    end

    private

    def parse_valgrind_output
      require "nokogiri"

      @errors = []

      Nokogiri::XML::Reader(File.open(configuration.valgrind_xml_file.to_path)).each do |node|
        next unless node.name == "error" && node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT
        error_xml = Nokogiri::XML::Document.parse(node.outer_xml).root
        error = ValgrindError.new(configuration, error_xml)
        next if error.skip?
        @errors << error
      end
    end

    def output_valgrind_errors
      @errors.each do |error|
        configuration.output_io.puts error
        configuration.output_io.puts
      end
    end
  end
end
