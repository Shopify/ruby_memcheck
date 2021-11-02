# ruby_memcheck

This gem provides a sane way to use Valgrind's memcheck on your native extension gem.

## Table of contents

1. [What is this gem?](#what-is-this-gem)
    1. [Who should use this gem?](#who-should-use-this-gem)
    1. [How does it work?](#how-does-it-work)
    1. [Limitations](#limitations)
1. [Installation](#installation)
1. [Setup](#setup)

## What is this gem?

Valgrind's memcheck is a great tool to find and debug memory issues (e.g. memory leak, use-after-free, etc.). However, it doesn't work well on Ruby because Ruby does not free all of the memory it allocates during shutdown. This results in Valgrind reporting thousands (or more) false-positives, making it very difficult for Valgrind to actually be useful. This gem solves the problem by using heuristics to filter out false-positives.

### Who should use this gem?

Only gems with native extensions can use this gem. If your gem is written in plain Ruby, this gem is not useful for you.

### How does it work?

This gem runs Valgrind with the `--xml` option to generate a XML of all the errors. It will then parse the XML and use various heuristics based on the type of the error and the stack trace to filter out errors that are false-positives.

### Limitations

Because of the aggressive heuristics used to filter out false-positives, there are various limitations of what this gem can detect.

1. This gem is only expected to work on Linux.
1. It will not find memory leaks in Ruby. It filters out everything in Ruby.
1. It will not find memory leaks of allocations that occurred in Ruby (even if the memory leak is caused by your native extension).

    An example of this is if a string is allocated in Ruby, passed into your native extension, you change the pointer of the string without freeing the contents, so the contents of the string becomes leaked.
1. To filter out false-positives, it will only find definite leaks (i.e. memory regions with no pointers to it). It will not find possible leaks (i.e. memory regions with pointers to it).
1. It will not find leaks that occur in the `Init` function of your native extension.
1. It will not find uses of undefined values (e.g. conditional jumps depending on undefined values). This is just a technical limitation that has not been solved yet (contributions welcome!).

## Installation

```
gem install ruby_memcheck
```

## Setup

The easiest way to use this gem is to use it on your test suite (minitest or RSpec) using rake.

0. Install Valgrind.
1. In your Rakefile, require this gem.

    ```ruby
    require "ruby_memcheck"
    ```

    - **For RSpec:** If you're using RSpec, also add the following require.

      ```ruby
      require "ruby_memcheck/rspec/rake_task"
      ```

1. Configure the gem by calling `RubyMemcheck.config`. You must pass it your binary name. This is the same value you passed into `create_makefile` in your `extconf.rb` file. Make sure this value is correct or it will filter out almost everything as a false-positive!

    ```ruby
    RubyMemcheck.config(binary_name: "your_binary_name")
    ```
1. Setup the test task for your test framework.
    - **minitest**
    
      Locate your test task(s) in your Rakefile. You can identify it with a call to `Rake::TestTask.new`.

      Create a namespace under the test task and create a `RubyMemcheck::TestTask` with the same configuration.

      For example, if your Rakefile looked like this before:

      ```ruby
      Rake::TestTask.new(test: :compile) do |t|
        t.libs << "test"
        t.test_files = FileList["test/unit/**/*_test.rb"]
      end
      ```

      You can change it to look like this:

      ```ruby
      test_config = lambda do |t|
        t.libs << "test"
        t.test_files = FileList["test/**/*_test.rb"]
      end
      Rake::TestTask.new(test: :compile, &test_config)
      namespace :test do
        RubyMemcheck::TestTask.new(valgrind: :compile, &test_config)
      end
      ```

    - **RSpec**

      Locate your rake task(s) in your Rakefile. You can identify it with a call to `RSpec::Core::RakeTask.new`.

      Create a namespace under the test task and create a `RubyMemcheck::RSpec::RakeTask` with the same configuration.

      For example, if your Rakefile looked like this before:

      ```ruby
      RubyMemcheck::RSpec::RakeTask.new(spec: :compile)
      ```

      You can change it to look like this:

      ```ruby
      RubyMemcheck::RSpec::RakeTask.new(spec: :compile)
      namespace :spec do
        RubyMemcheck::RSpec::RakeTask.new(valgrind: :compile)
      end
      ```

1. You're ready to run your test suite with Valgrind using `rake test:valgrind` or `rake spec:valgrind`! Note that this will take a while to run because Valgrind will make Ruby significantly slower.
1. (Optional) If you find false-positives in the output, you can create suppression files in a `suppressions` directory in the root directory of your gem. In this directory, you can create [Valgrind suppression files](https://wiki.wxwidgets.org/Valgrind_Suppression_File_Howto). The most basic suppression file is `your_binary_name_ruby.supp`. If you want some suppressions for only specific versions of Ruby, you can add the Ruby version to the filename. For example, `your_binary_name_ruby-3.supp` will suppress for any Rubies with a major version of 3 (e.g. 3.0.0, 3.1.1, etc.), while suppression file `your_binary_name_ruby-3.1.supp` will only be used for Ruby with a major and minor version of 3.1 (e.g. 3.1.0, 3.1.1, etc.).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
