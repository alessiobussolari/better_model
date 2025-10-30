# frozen_string_literal: true

require "test_helper"
require "generators/better_model/traceable/traceable_generator"

module BetterModel
  module Generators
    class TraceableGeneratorTest < Rails::Generators::TestCase
      tests BetterModel::Generators::TraceableGenerator
      destination File.expand_path("../../tmp", __dir__)
      setup :prepare_destination

  # ============================================================================
  # Basic Generation Tests - Default Behavior
  # ============================================================================

  test "generator runs successfully without options" do
    assert_nothing_raised do
      run_generator
    end
  end

  test "no migration created by default without --create-table option" do
    run_generator
    assert_no_migration "db/migrate/create_model_versions.rb"
  end

  test "no migration created with model argument but without --create-table" do
    run_generator [ "Article" ]
    assert_no_migration "db/migrate/create_article_versions.rb"
  end

  # ============================================================================
  # Create Table Option Tests
  # ============================================================================

  test "migration IS created when --create-table option is provided" do
    run_generator [ "Article", "--create-table" ]
    assert_migration "db/migrate/create_article_versions.rb"
  end

  test "migration class name matches model name" do
    run_generator [ "Order", "--create-table" ]
    assert_migration "db/migrate/create_order_versions.rb" do |migration|
      assert_match(/class CreateOrderVersions/, migration)
    end
  end

  test "migration creates new table with default naming" do
    run_generator [ "Article", "--create-table" ]
    assert_migration "db/migrate/create_article_versions.rb" do |migration|
      assert_match(/create_table :article_versions/, migration)
    end
  end

  # ============================================================================
  # Table Name Option Tests
  # ============================================================================

  test "custom table name via --table-name option" do
    run_generator [ "Article", "--create-table", "--table-name=custom_audit_log" ]
    assert_migration "db/migrate/create_custom_audit_log.rb"
  end

  test "custom table name affects migration class name" do
    run_generator [ "Order", "--create-table", "--table-name=order_history" ]
    assert_migration "db/migrate/create_order_history.rb" do |migration|
      assert_match(/class CreateOrderHistory/, migration)
    end
  end

  test "custom table name affects create_table statement" do
    run_generator [ "User", "--create-table", "--table-name=user_audit_trail" ]
    assert_migration "db/migrate/create_user_audit_trail.rb" do |migration|
      assert_match(/create_table :user_audit_trail/, migration)
    end
  end

  # ============================================================================
  # Default Table Naming Tests
  # ============================================================================

  test "default table name is {model}_versions with Article" do
    run_generator [ "Article", "--create-table" ]
    assert_migration "db/migrate/create_article_versions.rb" do |migration|
      assert_match(/create_table :article_versions/, migration)
    end
  end

  test "default table name is {model}_versions with User" do
    run_generator [ "User", "--create-table" ]
    assert_migration "db/migrate/create_user_versions.rb" do |migration|
      assert_match(/create_table :user_versions/, migration)
    end
  end

  test "default table name handles multi-word models" do
    run_generator [ "BlogPost", "--create-table" ]
    assert_migration "db/migrate/create_blog_post_versions.rb" do |migration|
      assert_match(/create_table :blog_post_versions/, migration)
    end
  end

  test "default table name with no argument uses model_versions" do
    run_generator [ "--create-table" ]
    assert_migration "db/migrate/create_model_versions.rb" do |migration|
      assert_match(/create_table :model_versions/, migration)
    end
  end

  # ============================================================================
  # Table Structure Tests - Columns
  # ============================================================================

  test "migration includes item_type column" do
    run_generator [ "Article", "--create-table" ]
    assert_migration "db/migrate/create_article_versions.rb" do |migration|
      assert_match(/t\.string :item_type, null: false/, migration)
    end
  end

  test "migration includes item_id column" do
    run_generator [ "Article", "--create-table" ]
    assert_migration "db/migrate/create_article_versions.rb" do |migration|
      assert_match(/t\.integer :item_id, null: false/, migration)
    end
  end

  test "migration includes event column" do
    run_generator [ "Article", "--create-table" ]
    assert_migration "db/migrate/create_article_versions.rb" do |migration|
      assert_match(/t\.string :event, null: false/, migration)
    end
  end

  test "migration includes object_changes column as JSON" do
    run_generator [ "Article", "--create-table" ]
    assert_migration "db/migrate/create_article_versions.rb" do |migration|
      assert_match(/t\.json :object_changes/, migration)
    end
  end

  test "migration includes updated_by_id column" do
    run_generator [ "Article", "--create-table" ]
    assert_migration "db/migrate/create_article_versions.rb" do |migration|
      assert_match(/t\.integer :updated_by_id/, migration)
    end
  end

  test "migration includes updated_reason column" do
    run_generator [ "Article", "--create-table" ]
    assert_migration "db/migrate/create_article_versions.rb" do |migration|
      assert_match(/t\.string :updated_reason/, migration)
    end
  end

  test "migration includes created_at column" do
    run_generator [ "Article", "--create-table" ]
    assert_migration "db/migrate/create_article_versions.rb" do |migration|
      assert_match(/t\.datetime :created_at, null: false/, migration)
    end
  end

  # ============================================================================
  # Table Structure Tests - Indexes
  # ============================================================================

  test "migration includes composite index on item" do
    run_generator [ "Article", "--create-table" ]
    assert_migration "db/migrate/create_article_versions.rb" do |migration|
      assert_match(/add_index :article_versions, \[ :item_type, :item_id \]/, migration)
    end
  end

  test "composite index includes custom name" do
    run_generator [ "Article", "--create-table" ]
    assert_migration "db/migrate/create_article_versions.rb" do |migration|
      assert_match(/name: "index_article_versions_on_item"/, migration)
    end
  end

  test "migration includes index on created_at column" do
    run_generator [ "Article", "--create-table" ]
    assert_migration "db/migrate/create_article_versions.rb" do |migration|
      assert_match(/add_index :article_versions, :created_at/, migration)
    end
  end

  test "migration includes index on updated_by_id column" do
    run_generator [ "Article", "--create-table" ]
    assert_migration "db/migrate/create_article_versions.rb" do |migration|
      assert_match(/add_index :article_versions, :updated_by_id/, migration)
    end
  end

  test "migration includes index on event column" do
    run_generator [ "Article", "--create-table" ]
    assert_migration "db/migrate/create_article_versions.rb" do |migration|
      assert_match(/add_index :article_versions, :event/, migration)
    end
  end

  # ============================================================================
  # Custom Table Name with Indexes Tests
  # ============================================================================

  test "custom table name affects all indexes" do
    run_generator [ "Order", "--create-table", "--table-name=order_audit" ]
    assert_migration "db/migrate/create_order_audit.rb" do |migration|
      assert_match(/add_index :order_audit, \[ :item_type, :item_id \]/, migration)
      assert_match(/add_index :order_audit, :created_at/, migration)
      assert_match(/add_index :order_audit, :updated_by_id/, migration)
      assert_match(/add_index :order_audit, :event/, migration)
    end
  end

  test "custom table name affects composite index name" do
    run_generator [ "User", "--create-table", "--table-name=user_changes" ]
    assert_migration "db/migrate/create_user_changes.rb" do |migration|
      assert_match(/name: "index_user_changes_on_item"/, migration)
    end
  end

  # ============================================================================
  # Migration Version Tests
  # ============================================================================

  test "generated migration includes correct ActiveRecord migration version" do
    run_generator [ "Article", "--create-table" ]
    assert_migration "db/migrate/create_article_versions.rb" do |migration|
      assert_match(/ActiveRecord::Migration\[\d+\.\d+\]/, migration)
    end
  end

  # ============================================================================
  # Combined Options Tests
  # ============================================================================

  test "multi-word model with create-table option" do
    run_generator [ "BlogPost", "--create-table" ]
    assert_migration "db/migrate/create_blog_post_versions.rb" do |migration|
      assert_match(/class CreateBlogPostVersions/, migration)
      assert_match(/create_table :blog_post_versions/, migration)
    end
  end

  test "multi-word model with custom table name" do
    run_generator [ "OrderItem", "--create-table", "--table-name=order_item_history" ]
    assert_migration "db/migrate/create_order_item_history.rb" do |migration|
      assert_match(/class CreateOrderItemHistory/, migration)
      assert_match(/create_table :order_item_history/, migration)
      assert_match(/add_index :order_item_history/, migration)
    end
  end
    end
  end
end
