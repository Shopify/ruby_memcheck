# frozen_string_literal: true

require "nokogiri"

module RubyMemcheck
  module XmlBackend
    class NokogiriNodeAdapter < NodeAdapter
      private

      def find_one(path)
        @node.at_xpath(path)
      end

      def find_all(path)
        @node.xpath(path)
      end
    end

    class NokogiriBackend
      def each_error(file)
        File.open(file) do |io|
          reader = Nokogiri::XML::Reader(io) do |config| # rubocop:disable Style/SymbolProc
            config.huge
          end

          reader.each do |node|
            next unless node.name == "error" && node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT

            yield parse(node.outer_xml)
          end
        end
      end

      def parse(xml)
        NokogiriNodeAdapter.new(Nokogiri::XML::Document.parse(xml).root)
      end
    end
  end
end
