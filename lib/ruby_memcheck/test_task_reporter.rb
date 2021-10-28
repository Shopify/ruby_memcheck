# frozen_string_literal: true

module RubyMemcheck
  module TestTaskReporter
    VALGRIND_REPORT_MSG = "Valgrind reported errors (e.g. memory leak or use-after-free)"

    attr_reader :errors

    private

    def report_valgrind_errors
      if configuration.valgrind_xml_dir
        parse_valgrind_output
        remove_valgrind_xml_files

        unless errors.empty?
          output_valgrind_errors
          raise VALGRIND_REPORT_MSG
        end
      end
    end

    def parse_valgrind_output
      require "nokogiri"

      @errors = []

      Dir[File.join(configuration.valgrind_xml_dir, "*")].each do |file|
        Nokogiri::XML::Reader(File.open(file)).each do |node|
          next unless node.name == "error" && node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT
          error_xml = Nokogiri::XML::Document.parse(node.outer_xml).root
          error = ValgrindError.new(configuration, error_xml)
          next if error.skip?
          @errors << error
        end
      end
    end

    def output_valgrind_errors
      @errors.each do |error|
        configuration.output_io.puts error
        configuration.output_io.puts
      end
    end

    def remove_valgrind_xml_files
      FileUtils.rm_rf(configuration.valgrind_xml_dir)
    end
  end
end
