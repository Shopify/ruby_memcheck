# frozen_string_literal: true

module RubyMemcheck
  class Stack
    attr_reader :frames

    def initialize(configuration, stack_xml)
      @frames = stack_xml.xpath("frame").map { |frame| Frame.new(configuration, frame) }
    end
  end
end
