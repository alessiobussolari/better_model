# frozen_string_literal: true

require "test_helper"
require "generators/better_model/stateable/stateable_generator"

module BetterModel
  module Generators
    class StateableGeneratorTest < Rails::Generators::TestCase
      tests BetterModel::Generators::StateableGenerator
      destination File.expand_path("../../tmp", __dir__)
      setup :prepare_destination

  # ============================================================================
  # Basic Generation Tests
  # ============================================================================

  test "generator runs successfully with model name" do
    run_generator [ "Article" ]
    assert_migration "db/migrate/add_stateable_to_articles.rb"
  end

  test "migration includes correct class name" do
    run_generator [ "Article" ]
    assert_migration "db/migrate/add_stateable_to_articles.rb" do |migration|
      assert_match(/class AddStateableToArticles/, migration)
    end
  end

  test "migration includes change_table for correct table name" do
    run_generator [ "Article" ]
    assert_migration "db/migrate/add_stateable_to_articles.rb" do |migration|
      assert_match(/change_table :articles/, migration)
    end
  end

  # ============================================================================
  # State Column Tests
  # ============================================================================

  test "migration adds state column" do
    run_generator [ "Article" ]
    assert_migration "db/migrate/add_stateable_to_articles.rb" do |migration|
      assert_match(/t\.string :state/, migration)
    end
  end

  test "state column is NOT NULL" do
    run_generator [ "Article" ]
    assert_migration "db/migrate/add_stateable_to_articles.rb" do |migration|
      assert_match(/null: false/, migration)
    end
  end

  test "state column has default value with default initial state" do
    run_generator [ "Article" ]
    assert_migration "db/migrate/add_stateable_to_articles.rb" do |migration|
      assert_match(/default: "pending"/, migration)
    end
  end

  # ============================================================================
  # Initial State Option Tests
  # ============================================================================

  test "accepts custom initial state via --initial-state option" do
    run_generator [ "Article", "--initial-state=draft" ]
    assert_migration "db/migrate/add_stateable_to_articles.rb" do |migration|
      assert_match(/default: "draft"/, migration)
    end
  end

  test "custom initial state replaces default pending state" do
    run_generator [ "Order", "--initial-state=confirmed" ]
    assert_migration "db/migrate/add_stateable_to_orders.rb" do |migration|
      assert_match(/default: "confirmed"/, migration)
      assert_no_match(/default: "pending"/, migration)
    end
  end

  test "initial state option accepts any string value" do
    run_generator [ "Task", "--initial-state=todo" ]
    assert_migration "db/migrate/add_stateable_to_tasks.rb" do |migration|
      assert_match(/default: "todo"/, migration)
    end
  end

  # ============================================================================
  # Index Tests
  # ============================================================================

  test "migration adds index on state column" do
    run_generator [ "Article" ]
    assert_migration "db/migrate/add_stateable_to_articles.rb" do |migration|
      assert_match(/add_index :articles, :state/, migration)
    end
  end

  # ============================================================================
  # Multiple Model Name Tests
  # ============================================================================

  test "works with singular model names" do
    run_generator [ "User" ]
    assert_migration "db/migrate/add_stateable_to_users.rb" do |migration|
      assert_match(/class AddStateableToUsers/, migration)
      assert_match(/change_table :users/, migration)
    end
  end

  test "works with multi-word model names" do
    run_generator [ "BlogPost" ]
    assert_migration "db/migrate/add_stateable_to_blog_posts.rb" do |migration|
      assert_match(/class AddStateableToBlogPosts/, migration)
      assert_match(/change_table :blog_posts/, migration)
    end
  end

  test "properly converts model name to table name" do
    run_generator [ "OrderItem" ]
    assert_migration "db/migrate/add_stateable_to_order_items.rb" do |migration|
      assert_match(/change_table :order_items/, migration)
      assert_match(/add_index :order_items, :state/, migration)
    end
  end

  # ============================================================================
  # Migration Version Tests
  # ============================================================================

  test "generated migration includes correct ActiveRecord migration version" do
    run_generator [ "Article" ]
    assert_migration "db/migrate/add_stateable_to_articles.rb" do |migration|
      assert_match(/ActiveRecord::Migration\[\d+\.\d+\]/, migration)
    end
  end

  # ============================================================================
  # Combined Options Tests
  # ============================================================================

  test "multi-word model with custom initial state" do
    run_generator [ "BlogPost", "--initial-state=published" ]
    assert_migration "db/migrate/add_stateable_to_blog_posts.rb" do |migration|
      assert_match(/class AddStateableToBlogPosts/, migration)
      assert_match(/change_table :blog_posts/, migration)
      assert_match(/default: "published"/, migration)
      assert_match(/add_index :blog_posts, :state/, migration)
    end
  end
    end
  end
end
