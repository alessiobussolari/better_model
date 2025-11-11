# frozen_string_literal: true

require_relative "stateable_error"

module BetterModel
  module Errors
    module Stateable
      class CheckFailedError < StateableError; end
    end
  end
end
