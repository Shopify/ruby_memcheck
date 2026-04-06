# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "ruby_memcheck"

require "minitest/autorun"

module RubyMemcheck
  def self.test_xml_backends
    backends = []

    begin
      require "ruby_memcheck/xml_backend/nokogiri_backend"
      backends << XmlBackend::NokogiriBackend.new
    rescue LoadError
      nil
    end

    begin
      require "ruby_memcheck/xml_backend/libxml_backend"
      backends << XmlBackend::LibxmlBackend.new
    rescue LoadError
      nil
    end

    backends
  end
end

if ENV["CI"]
  require "etc"
  ENV["NCPU"] ||= Etc.nprocessors.to_s
  require "minitest/parallel_fork"
end
