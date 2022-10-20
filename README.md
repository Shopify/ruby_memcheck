# ruby_memcheck

This gem provides a sane way to use Valgrind's memcheck on your native extension gem.

## Table of contents

1. [What is this gem?](#what-is-this-gem)
    1. [Who should use this gem?](#who-should-use-this-gem)
    1. [How does it work?](#how-does-it-work)
    1. [Limitations](#limitations)
1. [Installation](#installation)
1. [Setup](#setup)
1. [Configuration](#configuration)
1. [Suppression files](#suppression-files)
1. [License](#license)

## What is this gem?

Valgrind's memcheck is a great tool to find and debug memory issues (e.g. memory leak, use-after-free, etc.). However, it doesn't work well on Ruby because Ruby does not free all of the memory it allocates during shutdown. This results in Valgrind reporting thousands (or more) false positives, making it very difficult for Valgrind to actually be useful. This gem solves the problem by using heuristics to filter out false positives.

### Who should use this gem?

Only gems with native extensions can use this gem. If your gem is written in plain Ruby, this gem is not useful for you.

### How does it work?

This gem runs Valgrind with the `--xml` option to generate an XML of all the errors. It will then parse the XML and use various heuristics based on the type of the error and the stack trace to filter out errors that are false positives.

For more details, read [this blog post](https://blog.peterzhu.ca/ruby-memcheck/).

### Limitations

Because of the aggressive heuristics used to filter out false positives, there are various limitations of what this gem can detect.

1. This gem is only expected to work on Linux.
1. This gem runs your gem's test suite to find errors and memory leaks. It will only be able to report errors on code paths that are covered by your tests. So make sure your test suite has good coverage!
1. It will not find memory leaks in Ruby. It filters out everything in Ruby.
1. It will not find memory leaks of allocations that occurred in Ruby (even if the memory leak is caused by your native extension).

    An example of this is if a string is allocated in Ruby, passed into your native extension, you change the pointer of the string without freeing the contents, so the contents of the string becomes leaked.
1. To filter out false positives, it will only find definite leaks (i.e. memory regions with no pointers to it). It will not find possible leaks (i.e. memory regions with pointers to it).
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
      RSpec::Core::RakeTask.new(spec: :compile)
      ```

      You can change it to look like this:

      ```ruby
      RSpec::Core::RakeTask.new(spec: :compile)
      namespace :spec do
        RubyMemcheck::RSpec::RakeTask.new(valgrind: :compile)
      end
      ```

1. You're ready to run your test suite with Valgrind using `rake test:valgrind` or `rake spec:valgrind`! Note that this will take a while to run because Valgrind will make Ruby significantly slower.
1. (Optional) If you find false positives in the output, you can create Valgrind suppression files. See the [`Suppression files`](#suppression-files) section for more details.

## Configuration

When you run `RubyMemcheck.config`, you are creating a default `RubyMemcheck::Configuration`. By default, the Rake tasks for minitest and RSpec will use this configuration. You can also manually pass in a `Configuration` object as the first argument to the constructor of `RubyMemcheck::TestTask` or `RubyMemcheck::RSpec::RakeTask` to use a different `Configuration` object rather than the default one.

`RubyMemcheck::Configuration` accepts a variety of keyword arguments. Here are all the arguments:

- `binary_name`: Required. The binary name of your native extension gem. This is the same value you passed into `create_makefile` in your `extconf.rb` file.
- `ruby`: Optional. The command to run to invoke Ruby. Defaults to the Ruby that is currently being used.
- `valgrind`: Optional. The command to run to invoke Valgrind. Defaults to the string `"valgrind"`.
- `valgrind_options`: Optional. Array of options to pass into Valgrind. This is only present as an escape hatch, so avoid using it. This may be deprecated or removed in future versions.
- `valgrind_suppressions_dir`: Optional. The string path of the directory that stores suppression files for Valgrind. See the [`Suppression files`](#suppression-files) section for more details. Defaults to `suppressions`.
- `valgrind_generate_suppressions`: Optional. Whether suppressions should also be outputted along with the errors. the [`Suppression files`](#suppression-files) section for more details. Defaults to `false`.
- `skipped_ruby_functions`: Optional. Ruby functions that are ignored because they are considered a call back into Ruby. This is only present as an escape hatch, so avoid using it. If you find another Ruby function that is a false positive because it calls back into Ruby, please send a patch into this repo. Otherwise, use a Valgrind suppression file.
- `valgrind_xml_dir`: Optional. The directory to store temporary XML files for Valgrind. It defaults to a temporary directory. This is present for development debugging, so you shouldn't have to use it.
- `output_io`: Optional. The `IO` object to output Valgrind errors to. Defaults to standard error.

## Suppression files

If you find false positives in the output, you can create suppression files in a `suppressions` directory in the root directory of your gem. In this directory, you can create [Valgrind suppression files](https://wiki.wxwidgets.org/Valgrind_Suppression_File_Howto).

The most basic suppression file is `ruby.supp`. If you want some suppressions for only specific versions of Ruby, you can add the Ruby version to the filename. For example, `ruby-3.supp` will suppress for any Rubies with a major version of 3 (e.g. 3.0.0, 3.1.1, etc.), while suppression file `ruby-3.1.supp` will only be used for Ruby with a major and minor version of 3.1 (e.g. 3.1.0, 3.1.1, etc.).

## Success stories

Let's celebrate wins from this gem! If this gem was useful for you, please share your story below too!

- [`liquid-c`](https://github.com/Shopify/liquid-c):
  - Found 2 memory leaks: [#157](https://github.com/Shopify/liquid-c/pull/157), [#161](https://github.com/Shopify/liquid-c/pull/161)
  - Running on CI: [#162](https://github.com/Shopify/liquid-c/pull/162)
- [`nokogiri`](https://github.com/sparklemotion/nokogiri):
  - Found 5 memory leaks: [4 in #2345](https://github.com/sparklemotion/nokogiri/pull/2345), [#2347](https://github.com/sparklemotion/nokogiri/pull/2347)
  - CI is WIP: [#2344](https://github.com/sparklemotion/nokogiri/pull/2344)
- [`rotoscope`](https://github.com/Shopify/rotoscope):
  - Found a [memory leak in Ruby TracePoint](https://bugs.ruby-lang.org/issues/18264)
  - Running on CI: [#89](https://github.com/Shopify/rotoscope/pull/89)
- [`protobuf`](https://github.com/protocolbuffers/protobuf):
  - Found 1 memory leak: [#9150](https://github.com/protocolbuffers/protobuf/pull/9150)
- [`gRPC`](https://github.com/grpc/grpc):
  - Found 1 memory leak: [#27900](https://github.com/grpc/grpc/pull/27900)

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
