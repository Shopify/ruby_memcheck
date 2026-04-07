# frozen_string_literal: true

require "test_helper"

module RubyMemcheck
  class XmlBackendTest < Minitest::Test
    XML = <<~XML
      <valgrindoutput>
        <error>
          <kind>Leak_DefinitelyLost</kind>
          <xwhat>
            <text>100 bytes in 1 blocks are definitely lost</text>
          </xwhat>
          <stack>
            <frame>
              <fn>c_test_one_memory_leak</fn>
              <obj>/tmp/ruby_memcheck_c_test_one.so</obj>
            </frame>
          </stack>
        </error>
      </valgrindoutput>
    XML

    def test_prefers_libxml_when_available
      assert_equal("RubyMemcheck::XmlBackend::LibxmlBackend", XmlBackend.backend_class.name)
    end

    def test_each_error_with_each_available_backend
      Tempfile.create(["ruby_memcheck", ".xml"]) do |file|
        file.write(XML)
        file.flush

        RubyMemcheck.test_xml_backends.each do |backend|
          errors = []

          backend.each_error(file.path) do |error|
            errors << error
          end

          assert_equal(1, errors.length)
          assert_equal("Leak_DefinitelyLost", errors.first.at_xpath("kind").content)
          assert_equal(
            "100 bytes in 1 blocks are definitely lost",
            errors.first.at_xpath("xwhat/text").content,
          )
        end
      end
    end
  end
end
