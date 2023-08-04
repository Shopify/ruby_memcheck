# frozen_string_literal: true

require "test_helper"
require "nokogiri"

module RubyMemcheck
  class RubyMemcheckSuppressionTest < Minitest::Test
    def setup
      @configuration = Configuration.new
    end

    def test_given_a_suppression_node
      suppression = ::Nokogiri::XML(<<~EOF).at_xpath("//suppression")
        <foo>
          <suppression>
            <sname>insert_a_suppression_name_here</sname>
            <skind>Memcheck:Leak</skind>
            <skaux>match-leak-kinds: definite</skaux>
            <sframe> <fun>malloc</fun> </sframe>
            <sframe> <fun>objspace_xmalloc0</fun> </sframe>
            <sframe> <fun>ruby_xmalloc0</fun> </sframe>
            <sframe> <obj>/usr/lib/libX11.so.6.3.0</fun> </sframe>
            <sframe> <fun>ruby_xmalloc_body</fun> </sframe>
            <sframe> <fun>ruby_xmalloc</fun> </sframe>
          </suppression>
        </foo>
      EOF
      expected = <<~EOF
        {
          insert_a_suppression_name_here
          Memcheck:Leak
          fun:malloc
          fun:objspace_xmalloc0
          fun:ruby_xmalloc0
          obj:/usr/lib/libX11.so.6.3.0
          fun:ruby_xmalloc_body
          fun:ruby_xmalloc
        }
      EOF
      assert_equal(
        expected,
        RubyMemcheck::Suppression.new(@configuration, suppression).to_s,
      )
    end
  end
end
