require "test_helper"

class BetterModelTest < ActiveSupport::TestCase
  test "it has a version number" do
    assert BetterModel::VERSION
    assert_kind_of String, BetterModel::VERSION
    assert_match(/\d+\.\d+\.\d+/, BetterModel::VERSION)
  end

  test "including BetterModel includes Statusable concern" do
    test_class = Class.new(ApplicationRecord) do
      self.table_name = "articles"
      include BetterModel

      is :test_status, -> { true }
    end

    instance = test_class.new
    assert instance.respond_to?(:is?), "Should have is? method from Statusable"
    assert instance.respond_to?(:is_test_status?), "Should have dynamic is_test_status? method"
    assert instance.respond_to?(:statuses), "Should have statuses method from Statusable"
  end

  test "including BetterModel makes Statusable DSL available" do
    test_class = Class.new(ApplicationRecord) do
      self.table_name = "articles"
      include BetterModel

      is :active, -> { status == "active" }
      is :inactive, -> { status == "inactive" }
    end

    assert_equal [:active, :inactive].sort, test_class.defined_statuses.sort
    assert test_class.status_defined?(:active)
    assert test_class.status_defined?(:inactive)
  end

  test "individual concerns can still be included separately" do
    test_class = Class.new(ApplicationRecord) do
      self.table_name = "articles"
      include BetterModel::Statusable  # Include only Statusable

      is :test_status, -> { true }
    end

    instance = test_class.new
    assert instance.respond_to?(:is?), "Should have is? method from Statusable"
    assert instance.respond_to?(:statuses), "Should have statuses method from Statusable"
  end

  test "BetterModel works with actual model instances" do
    article = Article.new(status: "draft", view_count: 0)
    assert article.respond_to?(:is_draft?)
    assert article.is_draft?
    refute article.is_published?
  end

  test "including BetterModel multiple times does not cause errors" do
    assert_nothing_raised do
      Class.new(ApplicationRecord) do
        self.table_name = "articles"
        include BetterModel
        include BetterModel  # Should not raise error

        is :test, -> { true }
      end
    end
  end
end
