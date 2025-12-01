# frozen_string_literal: true

require "rails_helper"
require "better_model/generators/install_generator"

RSpec.describe BetterModel::Generators::InstallGenerator, type: :generator do
  # Use a temporary directory for generator output
  destination File.expand_path("../../tmp", __dir__)

  before do
    prepare_destination
  end

  after do
    FileUtils.rm_rf(destination_root)
  end

  describe "#create_initializer" do
    it "creates the initializer file" do
      run_generator

      expect(File.exist?(File.join(destination_root, "config/initializers/better_model.rb"))).to be true
    end

    it "creates file with correct content" do
      run_generator

      content = File.read(File.join(destination_root, "config/initializers/better_model.rb"))

      expect(content).to include("frozen_string_literal: true")
      expect(content).to include("BetterModel.configure do |config|")
      expect(content).to include("searchable_max_per_page")
      expect(content).to include("searchable_default_per_page")
      expect(content).to include("strict_mode")
      expect(content).to include("logger")
    end

    it "contains commented configuration examples" do
      run_generator

      content = File.read(File.join(destination_root, "config/initializers/better_model.rb"))

      # Check for commented examples
      expect(content).to include("# config.searchable_max_per_page = 100")
      expect(content).to include("# config.searchable_default_per_page = 25")
      expect(content).to include("# config.strict_mode = true")
      expect(content).to include("# config.logger = Rails.logger")
    end
  end

  describe "class configuration" do
    it "has source_root set" do
      expect(described_class.source_root).to be_present
    end

    it "has description" do
      expect(described_class.desc).to include("Install BetterModel")
    end

    it "inherits from Rails::Generators::Base" do
      expect(described_class.ancestors).to include(Rails::Generators::Base)
    end
  end
end
