# frozen_string_literal: true

require_relative "validatable_error"

module BetterModel
  module Errors
    module Validatable
      class NotEnabledError < ValidatableError; end
    end
  end
end
