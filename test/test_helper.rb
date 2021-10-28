# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "ruby_memcheck"

require "minitest/autorun"

if ENV["CI"]
  require "etc"
  ENV["NCPU"] ||= Etc.nprocessors.to_s
  require "minitest/parallel_fork"
end
