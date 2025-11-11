# frozen_string_literal: true

require_relative "traceable_error"

module BetterModel
  module Errors
    module Traceable
      class NotEnabledError < TraceableError; end
    end
  end
end
