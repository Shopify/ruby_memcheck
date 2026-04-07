# frozen_string_literal: true

require "test_helper"

module RubyMemcheck
  class ValgrindErrorTest < Minitest::Test
    def setup
      @configuration = Configuration.new
    end

    def test_raises_when_suppressions_generated_but_not_configured
      RubyMemcheck.test_xml_backends.each do |backend|
        output = backend.parse(<<~XML)
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
          </error>
        XML

        error = assert_raises do
          RubyMemcheck::ValgrindError.new(@configuration, [], output)
        end
        assert_equal(ValgrindError::SUPPRESSION_NOT_CONFIGURED_ERROR_MSG, error.message)
      end
    end
  end
end
