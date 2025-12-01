# frozen_string_literal: true

require "rails_helper"
require "generators/better_model/traceable/traceable_generator"

RSpec.describe BetterModel::Generators::TraceableGenerator, type: :generator do
  destination File.expand_path("../../../tmp/generators", __dir__)

  before do
    prepare_destination
  end

  describe "generator" do
    it "is defined" do
      expect(described_class).to be < Rails::Generators::Base
    end

    it "has source root" do
      expect(described_class.source_root).to include("templates")
    end

    it "accepts name argument" do
      expect(described_class.arguments.map(&:name)).to include("name")
    end
  end

  describe "without --create-table option" do
    it "does not create migration" do
      run_generator [ "Article" ]
      expect(Dir.glob("#{destination_root}/db/migrate/*.rb")).to be_empty
    end
  end

  describe "with --create-table option" do
    before { run_generator [ "Article", "--create-table" ] }

    it "creates migration file" do
      migration_files = Dir.glob("#{destination_root}/db/migrate/*_create_article_versions.rb")
      expect(migration_files.length).to eq(1)
    end

    it "migration creates correct table" do
      migration_file = Dir.glob("#{destination_root}/db/migrate/*_create_article_versions.rb").first
      content = File.read(migration_file)
      expect(content).to include("create_table :article_versions")
    end

    it "migration includes required columns" do
      migration_file = Dir.glob("#{destination_root}/db/migrate/*_create_article_versions.rb").first
      content = File.read(migration_file)
      expect(content).to include("item_type")
      expect(content).to include("item_id")
      expect(content).to include("event")
      expect(content).to include("object_changes")
    end
  end

  describe "with --table-name option" do
    before { run_generator [ "Article", "--create-table", "--table-name=custom_versions" ] }

    it "uses custom table name" do
      migration_files = Dir.glob("#{destination_root}/db/migrate/*_create_custom_versions.rb")
      expect(migration_files.length).to eq(1)
    end

    it "migration creates table with custom name" do
      migration_file = Dir.glob("#{destination_root}/db/migrate/*_create_custom_versions.rb").first
      content = File.read(migration_file)
      expect(content).to include("create_table :custom_versions")
    end
  end

  describe "with different model names" do
    it "handles simple model name" do
      run_generator [ "User", "--create-table" ]
      migration_files = Dir.glob("#{destination_root}/db/migrate/*_create_user_versions.rb")
      expect(migration_files.length).to eq(1)
    end

    it "handles underscored model name" do
      run_generator [ "blog_post", "--create-table" ]
      migration_files = Dir.glob("#{destination_root}/db/migrate/*_create_blog_post_versions.rb")
      expect(migration_files.length).to eq(1)
    end
  end

  describe "timestamp generation" do
    it "generates valid timestamp format" do
      run_generator [ "Article", "--create-table" ]
      migration_file = Dir.glob("#{destination_root}/db/migrate/*.rb").first
      filename = File.basename(migration_file)
      timestamp = filename.split("_").first
      expect(timestamp).to match(/^\d{14}$/)
    end
  end
end
