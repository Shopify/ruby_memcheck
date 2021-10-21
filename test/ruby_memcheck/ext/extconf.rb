# frozen_string_literal: true

require "mkmf"

$warnflags&.gsub!(/-Wdeclaration-after-statement/, "")

create_makefile("ruby_memcheck_c_test")
