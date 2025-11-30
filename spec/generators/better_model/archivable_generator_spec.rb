# frozen_string_literal: true

require "rails_helper"
require "generators/better_model/archivable/archivable_generator"

RSpec.describe BetterModel::Generators::ArchivableGenerator, type: :generator do
  destination File.expand_path("../../../tmp/generators", __dir__)

  before do
    prepare_destination
  end

  describe "generator" do
    it "is defined" do
      expect(described_class).to be < Rails::Generators::NamedBase
    end

    it "includes Migration module" do
      expect(described_class.ancestors).to include(Rails::Generators::Migration)
    end

    it "has source root" do
      expect(described_class.source_root).to include("templates")
    end
  end

  describe "migration generation" do
    context "with default options" do
      before { run_generator ["Article"] }

      it "creates migration file" do
        migration_files = Dir.glob("#{destination_root}/db/migrate/*_add_archivable_to_articles.rb")
        expect(migration_files.length).to eq(1)
      end

      it "adds archived_at column" do
        migration_file = Dir.glob("#{destination_root}/db/migrate/*_add_archivable_to_articles.rb").first
        content = File.read(migration_file)
        # Template uses change_table with t.datetime :archived_at
        expect(content).to include(":archived_at")
        expect(content).to include("datetime")
      end

      it "adds index by default" do
        migration_file = Dir.glob("#{destination_root}/db/migrate/*_add_archivable_to_articles.rb").first
        content = File.read(migration_file)
        expect(content).to include("add_index")
      end

      it "includes migration class name" do
        migration_file = Dir.glob("#{destination_root}/db/migrate/*_add_archivable_to_articles.rb").first
        content = File.read(migration_file)
        expect(content).to include("class AddArchivableToArticles")
      end
    end

    context "with --with-tracking option" do
      before { run_generator ["Article", "--with-tracking"] }

      it "includes archived_by_id column" do
        migration_file = Dir.glob("#{destination_root}/db/migrate/*_add_archivable_to_articles.rb").first
        content = File.read(migration_file)
        expect(content).to include("archived_by_id")
      end

      it "includes archive_reason column" do
        migration_file = Dir.glob("#{destination_root}/db/migrate/*_add_archivable_to_articles.rb").first
        content = File.read(migration_file)
        expect(content).to include("archive_reason")
      end
    end

    context "with --with-by option" do
      before { run_generator ["Article", "--with-by"] }

      it "includes archived_by_id column" do
        migration_file = Dir.glob("#{destination_root}/db/migrate/*_add_archivable_to_articles.rb").first
        content = File.read(migration_file)
        expect(content).to include("archived_by_id")
      end

      it "does not include archive_reason column" do
        migration_file = Dir.glob("#{destination_root}/db/migrate/*_add_archivable_to_articles.rb").first
        content = File.read(migration_file)
        expect(content).not_to include("archive_reason")
      end
    end

    context "with --with-reason option" do
      before { run_generator ["Article", "--with-reason"] }

      it "includes archive_reason column" do
        migration_file = Dir.glob("#{destination_root}/db/migrate/*_add_archivable_to_articles.rb").first
        content = File.read(migration_file)
        expect(content).to include("archive_reason")
      end

      it "does not include archived_by_id column" do
        migration_file = Dir.glob("#{destination_root}/db/migrate/*_add_archivable_to_articles.rb").first
        content = File.read(migration_file)
        expect(content).not_to include("archived_by_id")
      end
    end

    context "with --skip-indexes option" do
      before { run_generator ["Article", "--skip-indexes"] }

      it "does not add indexes" do
        migration_file = Dir.glob("#{destination_root}/db/migrate/*_add_archivable_to_articles.rb").first
        content = File.read(migration_file)
        expect(content).not_to include("add_index")
      end
    end

    context "with different model names" do
      it "handles simple model name" do
        run_generator ["User"]
        migration_files = Dir.glob("#{destination_root}/db/migrate/*_add_archivable_to_users.rb")
        expect(migration_files.length).to eq(1)
      end

      it "handles underscored model name" do
        run_generator ["blog_post"]
        migration_files = Dir.glob("#{destination_root}/db/migrate/*_add_archivable_to_blog_posts.rb")
        expect(migration_files.length).to eq(1)
      end
    end
  end

  describe ".next_migration_number" do
    it "returns incrementing migration number" do
      number = described_class.next_migration_number(destination_root)
      expect(number).to be_a(String)
      expect(number.length).to be >= 14
    end
  end
end
