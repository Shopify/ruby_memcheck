module RubyMemcheck
  class Frame
    attr_reader :fn, :obj, :file, :line, :in_binary
    alias_method :in_binary?, :in_binary

    def initialize(configuration, frame_xml)
      @fn = frame_xml.at_xpath("fn")&.content
      @obj = frame_xml.at_xpath("obj")&.content
      # file and line may not be available
      @file = frame_xml.at_xpath("file")&.content
      @line = frame_xml.at_xpath("line")&.content

      @in_binary = configuration.frame_in_binary?(self)
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
