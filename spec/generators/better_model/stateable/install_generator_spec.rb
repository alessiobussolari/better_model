# frozen_string_literal: true

require "rails_helper"
require "generators/better_model/stateable/install_generator"

RSpec.describe BetterModel::Generators::Stateable::InstallGenerator, type: :generator do
  destination File.expand_path("../../../../tmp/generators", __dir__)

  before do
    prepare_destination
  end

  describe "generator" do
    it "is defined" do
      expect(described_class).to be < Rails::Generators::Base
    end

    it "includes Migration module" do
      expect(described_class.ancestors).to include(ActiveRecord::Generators::Migration)
    end

    it "has source root" do
      expect(described_class.source_root).to include("templates")
    end

    it "has default table_name option" do
      options = described_class.class_options
      expect(options[:table_name].default).to eq("state_transitions")
    end
  end

  describe "migration generation" do
    context "with default options" do
      before { run_generator }

      it "creates migration file" do
        migration_files = Dir.glob("#{destination_root}/db/migrate/*_create_state_transitions.rb")
        expect(migration_files.length).to eq(1)
      end

      it "creates state_transitions table" do
        migration_file = Dir.glob("#{destination_root}/db/migrate/*_create_state_transitions.rb").first
        content = File.read(migration_file)
        expect(content).to include("create_table :state_transitions")
      end

      it "includes required columns" do
        migration_file = Dir.glob("#{destination_root}/db/migrate/*_create_state_transitions.rb").first
        content = File.read(migration_file)
        # Actual template uses transitionable_type instead of item_type
        expect(content).to include("transitionable_type")
        expect(content).to include("transitionable_id")
        expect(content).to include("event")
        expect(content).to include("from_state")
        expect(content).to include("to_state")
      end
    end

    context "with --table-name option" do
      before { run_generator [ "--table-name=order_transitions" ] }

      it "creates migration with custom table name" do
        migration_file = Dir.glob("#{destination_root}/db/migrate/*_create_order_transitions.rb").first
        expect(migration_file).not_to be_nil
      end

      it "uses custom table name in migration" do
        migration_file = Dir.glob("#{destination_root}/db/migrate/*_create_order_transitions.rb").first
        content = File.read(migration_file)
        expect(content).to include("create_table :order_transitions")
      end
    end
  end
end
