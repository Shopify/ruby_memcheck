# frozen_string_literal: true

at_exit do
  File.open(ENV["RUBY_MEMCHECK_LOADED_FEATURES_FILE"], "w") do |f|
    f.write($LOADED_FEATURES.join("\n"))
  end

  GC.start
end
