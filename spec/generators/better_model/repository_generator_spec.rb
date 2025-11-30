# frozen_string_literal: true

require "rails_helper"
require "generators/better_model/repository/repository_generator"

RSpec.describe BetterModel::Generators::RepositoryGenerator, type: :generator do
  destination File.expand_path("../../../tmp/generators", __dir__)

  before do
    prepare_destination
  end

  describe "generator" do
    it "is defined" do
      expect(described_class).to be < Rails::Generators::NamedBase
    end

    it "has source root" do
      expect(described_class.source_root).to include("templates")
    end

    it "has default path option" do
      options = described_class.class_options
      expect(options[:path].default).to eq("app/repositories")
    end
  end

  describe "repository generation" do
    context "with default options" do
      before { run_generator ["Article"] }

      it "creates repository file" do
        repo_file = File.join(destination_root, "app/repositories/article_repository.rb")
        expect(File).to exist(repo_file)
      end

      it "repository contains correct class" do
        repo_file = File.join(destination_root, "app/repositories/article_repository.rb")
        content = File.read(repo_file)
        expect(content).to include("class ArticleRepository")
        expect(content).to include("def model_class")
        expect(content).to include("Article")
      end

      it "creates application_repository.rb" do
        app_repo = File.join(destination_root, "app/repositories/application_repository.rb")
        expect(File).to exist(app_repo)
      end

      it "application_repository contains base class" do
        app_repo = File.join(destination_root, "app/repositories/application_repository.rb")
        content = File.read(app_repo)
        expect(content).to include("class ApplicationRepository")
        expect(content).to include("BetterModel::Repositable::BaseRepository")
      end

      it "repository inherits from ApplicationRepository" do
        repo_file = File.join(destination_root, "app/repositories/article_repository.rb")
        content = File.read(repo_file)
        expect(content).to include("< ApplicationRepository")
      end
    end

    context "with --skip-base option" do
      before { run_generator ["Article", "--skip-base"] }

      it "creates repository file" do
        expect(File).to exist(File.join(destination_root, "app/repositories/article_repository.rb"))
      end

      it "does not create application_repository.rb" do
        expect(File).not_to exist(File.join(destination_root, "app/repositories/application_repository.rb"))
      end

      it "inherits from BaseRepository directly" do
        repo_file = File.join(destination_root, "app/repositories/article_repository.rb")
        content = File.read(repo_file)
        expect(content).to include("BetterModel::Repositable::BaseRepository")
      end
    end

    context "with --path option" do
      before { run_generator ["Article", "--path=app/services/repos"] }

      it "creates repository in custom path" do
        repo_file = File.join(destination_root, "app/services/repos/article_repository.rb")
        expect(File).to exist(repo_file)
      end
    end

    context "with --namespace option" do
      before { run_generator ["Article", "--namespace=Admin"] }

      it "namespaces the repository class" do
        repo_file = File.join(destination_root, "app/repositories/article_repository.rb")
        content = File.read(repo_file)
        # Namespace may be in different formats
        expect(content).to match(/Admin.*ArticleRepository|module Admin/)
      end
    end

    context "when ApplicationRepository already exists" do
      before do
        FileUtils.mkdir_p(File.join(destination_root, "app/repositories"))
        File.write(
          File.join(destination_root, "app/repositories/application_repository.rb"),
          "class ApplicationRepository; end"
        )
        run_generator ["Article"]
      end

      it "does not overwrite application_repository.rb" do
        app_repo_file = File.join(destination_root, "app/repositories/application_repository.rb")
        content = File.read(app_repo_file)
        expect(content).to eq("class ApplicationRepository; end")
      end
    end

    context "with different model names" do
      it "handles simple model name" do
        run_generator ["User"]
        expect(File).to exist(File.join(destination_root, "app/repositories/user_repository.rb"))
      end

      it "creates correct class name" do
        run_generator ["BlogPost"]
        repo_file = File.join(destination_root, "app/repositories/blog_post_repository.rb")
        content = File.read(repo_file)
        expect(content).to include("class BlogPostRepository")
        expect(content).to include("BlogPost")
      end
    end
  end

  describe "file structure" do
    it "creates proper directory structure" do
      run_generator ["Article"]
      expect(Dir).to exist(File.join(destination_root, "app/repositories"))
    end
  end
end
