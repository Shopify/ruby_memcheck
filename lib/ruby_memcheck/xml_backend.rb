# frozen_string_literal: true

module RubyMemcheck
  module XmlBackend
    LOAD_ERROR_MSG =
      "ruby_memcheck requires either nokogiri or libxml-ruby to parse Valgrind XML output"

    def self.create
      backend_class.new
    end

    def self.backend_class
      @backend_class ||= detect_backend_class
    end

    class NodeAdapter
      def initialize(node)
        @node = node
      end

      def at_xpath(path)
        wrap(find_one(path))
      end

      def xpath(path)
        find_all(path).map { |node| wrap(node) }
      end

      def content
        @node.content
      end

      def name
        @node.name
      end

      private

      def wrap(node)
        node && self.class.new(node)
      end
    end

    def self.detect_backend_class
      require "ruby_memcheck/xml_backend/libxml_backend"
      LibxmlBackend
    rescue LoadError
      require "ruby_memcheck/xml_backend/nokogiri_backend"
      NokogiriBackend
    rescue LoadError
      raise LoadError, LOAD_ERROR_MSG
    end
    private_class_method :detect_backend_class
  end
end
