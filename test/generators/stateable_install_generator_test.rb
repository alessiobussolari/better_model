# frozen_string_literal: true

require "test_helper"
require "generators/better_model/stateable/install_generator"

module BetterModel
  module Generators
    module Stateable
      class InstallGeneratorTest < Rails::Generators::TestCase
        tests BetterModel::Generators::Stateable::InstallGenerator
        destination File.expand_path("../../../tmp", __dir__)
        setup :prepare_destination

  # ============================================================================
  # Basic Generation Tests
  # ============================================================================

  test "generator runs successfully without options" do
    run_generator
    assert_migration "db/migrate/create_state_transitions.rb"
  end

  test "migration includes correct class name with default table name" do
    run_generator
    assert_migration "db/migrate/create_state_transitions.rb" do |migration|
      assert_match(/class CreateStateTransitions/, migration)
    end
  end

  test "migration creates new table with default name" do
    run_generator
    assert_migration "db/migrate/create_state_transitions.rb" do |migration|
      assert_match(/create_table :state_transitions/, migration)
    end
  end

  # ============================================================================
  # Table Name Option Tests
  # ============================================================================

  test "accepts custom table name via --table-name option" do
    run_generator ["--table-name=custom_transitions"]
    assert_migration "db/migrate/create_custom_transitions.rb"
  end

  test "custom table name affects migration class name" do
    run_generator ["--table-name=order_transitions"]
    assert_migration "db/migrate/create_order_transitions.rb" do |migration|
      assert_match(/class CreateOrderTransitions/, migration)
    end
  end

  test "custom table name affects create_table statement" do
    run_generator ["--table-name=article_transitions"]
    assert_migration "db/migrate/create_article_transitions.rb" do |migration|
      assert_match(/create_table :article_transitions/, migration)
    end
  end

  # ============================================================================
  # Table Structure Tests - Columns
  # ============================================================================

  test "migration includes transitionable_type column" do
    run_generator
    assert_migration "db/migrate/create_state_transitions.rb" do |migration|
      assert_match(/t\.string :transitionable_type, null: false/, migration)
    end
  end

  test "migration includes transitionable_id column" do
    run_generator
    assert_migration "db/migrate/create_state_transitions.rb" do |migration|
      assert_match(/t\.integer :transitionable_id, null: false/, migration)
    end
  end

  test "migration includes event column" do
    run_generator
    assert_migration "db/migrate/create_state_transitions.rb" do |migration|
      assert_match(/t\.string :event, null: false/, migration)
    end
  end

  test "migration includes from_state column" do
    run_generator
    assert_migration "db/migrate/create_state_transitions.rb" do |migration|
      assert_match(/t\.string :from_state, null: false/, migration)
    end
  end

  test "migration includes to_state column" do
    run_generator
    assert_migration "db/migrate/create_state_transitions.rb" do |migration|
      assert_match(/t\.string :to_state, null: false/, migration)
    end
  end

  test "migration includes metadata column as JSON" do
    run_generator
    assert_migration "db/migrate/create_state_transitions.rb" do |migration|
      assert_match(/t\.json :metadata/, migration)
    end
  end

  test "migration includes created_at column" do
    run_generator
    assert_migration "db/migrate/create_state_transitions.rb" do |migration|
      assert_match(/t\.datetime :created_at, null: false/, migration)
    end
  end

  # ============================================================================
  # Table Structure Tests - Indexes
  # ============================================================================

  test "migration includes composite index on transitionable" do
    run_generator
    assert_migration "db/migrate/create_state_transitions.rb" do |migration|
      assert_match(/add_index :state_transitions, \[:transitionable_type, :transitionable_id\]/, migration)
    end
  end

  test "composite index includes custom name" do
    run_generator
    assert_migration "db/migrate/create_state_transitions.rb" do |migration|
      assert_match(/name: "index_state_transitions_on_transitionable"/, migration)
    end
  end

  test "migration includes index on event column" do
    run_generator
    assert_migration "db/migrate/create_state_transitions.rb" do |migration|
      assert_match(/add_index :state_transitions, :event/, migration)
    end
  end

  test "migration includes index on from_state column" do
    run_generator
    assert_migration "db/migrate/create_state_transitions.rb" do |migration|
      assert_match(/add_index :state_transitions, :from_state/, migration)
    end
  end

  test "migration includes index on to_state column" do
    run_generator
    assert_migration "db/migrate/create_state_transitions.rb" do |migration|
      assert_match(/add_index :state_transitions, :to_state/, migration)
    end
  end

  test "migration includes index on created_at column" do
    run_generator
    assert_migration "db/migrate/create_state_transitions.rb" do |migration|
      assert_match(/add_index :state_transitions, :created_at/, migration)
    end
  end

  # ============================================================================
  # Custom Table Name with Indexes Tests
  # ============================================================================

  test "custom table name affects all indexes" do
    run_generator ["--table-name=custom_transitions"]
    assert_migration "db/migrate/create_custom_transitions.rb" do |migration|
      assert_match(/add_index :custom_transitions, \[:transitionable_type, :transitionable_id\]/, migration)
      assert_match(/add_index :custom_transitions, :event/, migration)
      assert_match(/add_index :custom_transitions, :from_state/, migration)
      assert_match(/add_index :custom_transitions, :to_state/, migration)
      assert_match(/add_index :custom_transitions, :created_at/, migration)
    end
  end

  test "custom table name affects composite index name" do
    run_generator ["--table-name=order_history"]
    assert_migration "db/migrate/create_order_history.rb" do |migration|
      assert_match(/name: "index_order_history_on_transitionable"/, migration)
    end
  end

  # ============================================================================
  # Migration Version Tests
  # ============================================================================

  test "generated migration includes correct ActiveRecord migration version" do
    run_generator
    assert_migration "db/migrate/create_state_transitions.rb" do |migration|
      assert_match(/ActiveRecord::Migration\[\d+\.\d+\]/, migration)
    end
  end
      end
    end
  end
end
