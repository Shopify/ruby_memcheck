# frozen_string_literal: true

require "test_helper"

class RubyMemcheckTest < Minitest::Test
  def setup
    RubyMemcheck.instance_variable_set(:@default_configuration, nil)
  end

  def test_config_sets_default_configuration
    config = RubyMemcheck.config

    assert_equal(config, RubyMemcheck.default_configuration)
  end

  def test_default_configuration_creates_new_configuration
    config = RubyMemcheck.default_configuration
    refute_nil(config)
    assert_equal(config, RubyMemcheck.default_configuration)
  end
end
