# frozen_string_literal: true

module BetterModel
  module Errors
    # Root error class for all BetterModel errors.
    # All module-specific errors inherit from this class.
    class BetterModelError < StandardError; end
  end
end
