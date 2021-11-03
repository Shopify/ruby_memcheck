# frozen_string_literal: true

module RubyMemcheck
  class Stack
    attr_reader :configuration, :frames

    def initialize(configuration, stack_xml)
      @configuration = configuration
      @frames = stack_xml.xpath("frame").map { |frame| Frame.new(configuration, frame) }
    end

    def skip?
      in_binary = false

      frames.each do |frame|
        fn = frame.fn

        if frame.in_ruby?
          # If a stack from from the binary was encountered first, then this
          # memory leak did not occur from Ruby
          unless in_binary
            # Skip this stack because it was called from Ruby
            return true if configuration.skipped_ruby_functions.any? { |r| r.match?(fn) }
          end
        elsif frame.in_binary?
          in_binary = true

          # Skip the Init function because it is only ever called once, so
          # leaks in it cannot cause memory bloat
          return true if fn == "Init_#{configuration.binary_name}"
        end
      end

      # Skip if the stack was never in the binary because it is very likely
      # not a leak in the native gem
      !in_binary
    end
  end
end
