# frozen_string_literal: true

# Helper module for creating dynamic test classes
# This mirrors the pattern used in the original Minitest tests
module DynamicClassHelper
  # Creates a dynamic test class that includes BetterModel
  #
  # @param name [String, Symbol] The constant name for the class
  # @param parent [Class] The parent class to inherit from (default: ApplicationRecord)
  # @param table [String] The table name to use (default: "articles")
  # @yield Optional block to evaluate in the class context
  # @return [Class] The newly created class
  def create_test_class(name, parent: ApplicationRecord, table: "articles", &block)
    klass = Class.new(parent) do
      self.table_name = table
      include BetterModel
    end

    stub_const(name.to_s, klass)
    klass.class_eval(&block) if block_given?
    klass
  end

  # Aliases for backward compatibility with existing test patterns
  def create_stateable_class(name, &block)
    create_test_class(name, &block)
  end

  def create_validatable_class(name, &block)
    create_test_class(name, &block)
  end

  def create_searchable_class(name, &block)
    create_test_class(name, &block)
  end

  def create_predicable_class(name, &block)
    create_test_class(name, &block)
  end

  def create_sortable_class(name, &block)
    create_test_class(name, &block)
  end

  def create_archivable_class(name, &block)
    create_test_class(name, &block)
  end

  def create_traceable_class(name, &block)
    create_test_class(name, &block)
  end

  def create_taggable_class(name, &block)
    create_test_class(name, &block)
  end

  def create_permissible_class(name, &block)
    create_test_class(name, &block)
  end

  def create_statusable_class(name, &block)
    create_test_class(name, &block)
  end

  def create_repositable_class(name, &block)
    create_test_class(name, &block)
  end
end

RSpec.configure do |config|
  config.include DynamicClassHelper
end
