# frozen_string_literal: true

module RubyMemcheck
  class Frame
    attr_reader :configuration, :fn, :obj, :file, :line

    def initialize(configuration, frame_xml)
      @configuration = configuration
      @fn = frame_xml.at_xpath("fn")&.content
      @obj = frame_xml.at_xpath("obj")&.content
      # file and line may not be available
      @file = frame_xml.at_xpath("file")&.content
      @line = frame_xml.at_xpath("line")&.content
    end

    def in_ruby?
      obj == configuration.ruby ||
        # Hack to fix Ruby built with --enabled-shared
        File.basename(obj) == "libruby.so.#{RUBY_VERSION}"
    end

    def in_binary?
      if obj
        File.basename(obj, ".*") == configuration.binary_name
      else
        false
      end
    end

    def to_s
      if file
        "#{fn} (#{file}:#{line})"
      elsif fn
        "#{fn} (at #{obj})"
      else
        "<unknown stack frame>"
      end
    end
  end
end
