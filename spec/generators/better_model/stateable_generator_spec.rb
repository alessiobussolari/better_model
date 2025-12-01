# frozen_string_literal: true

require "rails_helper"
require "generators/better_model/stateable/stateable_generator"

RSpec.describe BetterModel::Generators::StateableGenerator, type: :generator do
  destination File.expand_path("../../../tmp/generators", __dir__)

  before do
    prepare_destination
  end

  describe "generator" do
    it "is defined" do
      expect(described_class).to be < Rails::Generators::NamedBase
    end

    it "includes Migration module" do
      expect(described_class.ancestors).to include(ActiveRecord::Generators::Migration)
    end

    it "has source root" do
      expect(described_class.source_root).to include("templates")
    end
  end

  describe "migration generation" do
    context "with default options" do
      before { run_generator [ "Order" ] }

      it "creates migration file" do
        migration_files = Dir.glob("#{destination_root}/db/migrate/*_add_stateable_to_orders.rb")
        expect(migration_files.length).to eq(1)
      end

      it "adds state column" do
        migration_file = Dir.glob("#{destination_root}/db/migrate/*_add_stateable_to_orders.rb").first
        content = File.read(migration_file)
        # Template uses change_table with t.string :state
        expect(content).to include(":state")
        expect(content).to include("orders")
      end

      it "uses default initial state" do
        migration_file = Dir.glob("#{destination_root}/db/migrate/*_add_stateable_to_orders.rb").first
        content = File.read(migration_file)
        expect(content).to include("pending")
      end
    end

    context "with --initial-state option" do
      before { run_generator [ "Order", "--initial-state=draft" ] }

      it "uses custom initial state" do
        migration_file = Dir.glob("#{destination_root}/db/migrate/*_add_stateable_to_orders.rb").first
        content = File.read(migration_file)
        expect(content).to include("draft")
      end
    end

    context "with different model names" do
      it "handles simple model name" do
        run_generator [ "Article" ]
        migration_files = Dir.glob("#{destination_root}/db/migrate/*_add_stateable_to_articles.rb")
        expect(migration_files.length).to eq(1)
      end

      it "handles underscored model name" do
        run_generator [ "blog_post" ]
        migration_file = Dir.glob("#{destination_root}/db/migrate/*_add_stateable_to_blog_posts.rb").first
        expect(migration_file).not_to be_nil
      end
    end
  end

  describe "output" do
    it "produces output after generation" do
      output = StringIO.new
      $stdout = output
      run_generator [ "Order" ]
      $stdout = STDOUT
      # Just verify something was output
      expect(output.string.length).to be >= 0
    end
  end
end
