# frozen_string_literal: true

require_relative "../better_model_error"

module BetterModel
  module Errors
    module Taggable
      # Base error class for all Taggable-related errors.
      class TaggableError < BetterModelError
      end
    end
  end
end
