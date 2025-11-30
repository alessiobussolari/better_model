# frozen_string_literal: true

require "rails_helper"

RSpec.describe BetterModel do
  describe "VERSION" do
    it "has a version number" do
      expect(BetterModel::VERSION).not_to be_nil
    end

    it "is a string" do
      expect(BetterModel::VERSION).to be_a(String)
    end

    it "follows semantic versioning format" do
      expect(BetterModel::VERSION).to match(/\d+\.\d+\.\d+/)
    end
  end

  describe "including BetterModel" do
    context "with Statusable concern" do
      let(:test_class) do
        create_test_class("TestBetterModel1") do
          is :test_status, -> { true }
        end
      end

      let(:instance) { test_class.new }

      it "includes is? method from Statusable" do
        expect(instance).to respond_to(:is?)
      end

      it "creates dynamic is_test_status? method" do
        expect(instance).to respond_to(:is_test_status?)
      end

      it "includes statuses method from Statusable" do
        expect(instance).to respond_to(:statuses)
      end
    end

    context "with Statusable DSL" do
      let(:test_class) do
        create_test_class("TestBetterModel2") do
          is :active, -> { status == "active" }
          is :inactive, -> { status == "inactive" }
        end
      end

      it "registers defined statuses" do
        expect(test_class.defined_statuses.sort).to eq(%i[active inactive].sort)
      end

      it "recognizes active as defined status" do
        expect(test_class.status_defined?(:active)).to be true
      end

      it "recognizes inactive as defined status" do
        expect(test_class.status_defined?(:inactive)).to be true
      end
    end
  end

  describe "individual concerns" do
    let(:test_class) do
      klass = Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel::Statusable

        is :test_status, -> { true }
      end
      stub_const("TestBetterModel3", klass)
      klass
    end

    let(:instance) { test_class.new }

    it "can include only Statusable" do
      expect(instance).to respond_to(:is?)
    end

    it "provides statuses method when including only Statusable" do
      expect(instance).to respond_to(:statuses)
    end
  end

  describe "with actual model instances" do
    let(:article) { build(:article, status: "draft", view_count: 0) }

    it "responds to is_draft?" do
      expect(article).to respond_to(:is_draft?)
    end

    it "identifies draft articles" do
      expect(article.is_draft?).to be true
    end

    it "does not identify draft articles as published" do
      expect(article.is_published?).to be false
    end
  end

  describe "multiple inclusions" do
    it "does not raise errors when included multiple times" do
      expect do
        Class.new(ApplicationRecord) do
          self.table_name = "articles"
          include BetterModel
          include BetterModel

          is :test, -> { true }
        end
      end.not_to raise_error
    end
  end
end
