# frozen_string_literal: true

require "mkmf"

$warnflags&.gsub!("-Wdeclaration-after-statement", "") # rubocop:disable Style/GlobalVars

create_makefile("ruby_memcheck_c_test_one")
