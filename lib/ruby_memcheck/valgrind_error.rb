
module RubyMemcheck
  class ValgrindError
    attr_reader :kind, :msg, :stack

    def initialize(configuration, error)
      @kind = error.at_xpath("kind").content
      @msg =
        if kind_leak?
          error.at_xpath("xwhat/text").content
        else
          error.at_xpath("what").content
        end
      @stack = Stack.new(configuration, error.at_xpath("stack"))
      @configuration = configuration
    end

    def skip?
      if should_filter?
        @configuration.skip_stack?(stack)
      else
        false
      end
    end

    def to_s
      str = StringIO.new
      str << "#{msg}\n"
      stack.frames.each do |frame|
        if frame.in_binary?
          str << " *#{frame.to_s}\n"
        else
          str << "  #{frame.to_s}\n"
        end
      end
      str.string
    end

    private

    def should_filter?
      kind_leak?
    end

    def kind_leak?
      kind.start_with?("Leak_")
    end
  end
end
