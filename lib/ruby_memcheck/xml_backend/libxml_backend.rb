# frozen_string_literal: true

require "libxml-ruby"

module RubyMemcheck
  module XmlBackend
    class LibxmlNodeAdapter < NodeAdapter
      private

      def find_one(path)
        @node.find(path).first
      end

      def find_all(path)
        @node.find(path)
      end
    end

    class LibxmlBackend
      def each_error(file)
        reader = LibXML::XML::Reader.file(file)

        while reader.read
          next unless reader.node_type == LibXML::XML::Reader::TYPE_ELEMENT
          next unless reader.name == "error"

          yield parse(reader.read_outer_xml)
        end
      end

      def parse(xml)
        LibxmlNodeAdapter.new(LibXML::XML::Document.string(xml).root)
      end
    end
  end
end
