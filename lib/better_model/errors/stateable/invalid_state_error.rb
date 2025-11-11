# frozen_string_literal: true

require_relative "stateable_error"

module BetterModel
  module Errors
    module Stateable
      class InvalidStateError < StateableError; end
    end
  end
end
