# frozen_string_literal: true

require "ammeter/init"

# Helper for testing Rails generators
module GeneratorHelper
  extend ActiveSupport::Concern

  included do
    # Set destination for generated files
    destination File.expand_path("../../tmp/generators", __dir__)

    before do
      prepare_destination
    end
  end
end

RSpec.configure do |config|
  config.include GeneratorHelper, type: :generator
end
