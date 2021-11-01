# frozen_string_literal: true

require "test_helper"
require "nokogiri"

module RubyMemcheck
  class ValgrindErrorTest < Minitest::Test
    def setup
      @configuration = Configuration.new(binary_name: "ruby_memcheck_c_test")
    end

    def test_raises_when_suppressions_generated_but_not_configured
      output = ::Nokogiri::XML(<<~XML).at_xpath("//error")
        <error>
          <unique>0x1ab8</unique>
          <tid>1</tid>
          <kind>Leak_DefinitelyLost</kind>
          <xwhat>
            <text>48 bytes in 1 blocks are definitely lost in loss record 6,841 of 11,850</text>
            <leakedbytes>48</leakedbytes>
            <leakedblocks>1</leakedblocks>
          </xwhat>

          <stack>
          </stack>

          <suppression>
          </suppression>
        </foo>
      XML

      error = assert_raises do
        RubyMemcheck::ValgrindError.new(@configuration, output)
      end
      assert_equal(ValgrindError::SUPPRESSION_NOT_CONFIGURED_ERROR_MSG, error.message)
    end
  end
end
