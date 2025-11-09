# frozen_string_literal: true

require "test_helper"

module BetterModel
  class StateableSecurityTest < ActiveSupport::TestCase
    def setup
      # Crea una tabella temporanea per i test
      ActiveRecord::Migration.suppress_messages do
        ActiveRecord::Migration.create_table :secure_stateables, force: true do |t|
          t.string :state
          t.timestamps
        end
      end

      # Definisci il modello base
      @model_class = Class.new(ActiveRecord::Base) do
        self.table_name = "secure_stateables"
        include BetterModel::Stateable
      end
      Object.const_set(:SecureStateable, @model_class)
    end

    def teardown
      ActiveRecord::Migration.suppress_messages do
        ActiveRecord::Migration.drop_table :secure_stateables, if_exists: true
      end
      Object.send(:remove_const, :SecureStateable) if Object.const_defined?(:SecureStateable)
    end

    # ========================================
    # 1. IMMUTABILITÀ CONFIGURAZIONI
    # ========================================

    test "stateable config is frozen after setup" do
      SecureStateable.class_eval do
        stateable do
          state :draft
          state :published
        end
      end

      assert SecureStateable.stateable_config.frozen?, "Config should be frozen"
    end

    test "stateable states array is frozen after setup" do
      SecureStateable.class_eval do
        stateable do
          state :draft
          state :published
        end
      end

      assert SecureStateable.stateable_states.frozen?, "States array should be frozen"
    end

    test "stateable transitions hash is frozen after setup" do
      SecureStateable.class_eval do
        stateable do
          state :draft
          state :published
          transition :publish, from: :draft, to: :published
        end
      end

      assert SecureStateable.stateable_transitions.frozen?, "Transitions hash should be frozen"
    end

    test "cannot modify states array at runtime" do
      SecureStateable.class_eval do
        stateable do
          state :draft
        end
      end

      assert_raises(FrozenError) do
        SecureStateable.stateable_states << :hacked
      end
    end

    test "cannot modify config hash at runtime" do
      SecureStateable.class_eval do
        stateable do
          state :draft
        end
      end

      assert_raises(FrozenError) do
        SecureStateable.stateable_config[:malicious] = true
      end
    end

    test "cannot modify transitions at runtime" do
      SecureStateable.class_eval do
        stateable do
          state :draft
          state :published
          transition :publish, from: :draft, to: :published
        end
      end

      assert_raises(FrozenError) do
        SecureStateable.stateable_transitions[:hack] = {}
      end
    end

    # ========================================
    # 2. VALIDAZIONE PARAMETRI DSL
    # ========================================

    test "rejects non-symbol state names" do
      error = assert_raises(ArgumentError) do
        SecureStateable.class_eval do
          stateable do
            state "draft" # String invece di Symbol
          end
        end
      end

      assert_match(/must be a symbol/i, error.message)
    end

    test "rejects non-symbol event names in transitions" do
      error = assert_raises(ArgumentError) do
        SecureStateable.class_eval do
          stateable do
            state :draft
            state :published
            transition "publish", from: :draft, to: :published # String invece di Symbol
          end
        end
      end

      assert_match(/must be a symbol/i, error.message)
    end

    test "validates state exists before allowing transitions" do
      error = assert_raises(ArgumentError) do
        SecureStateable.class_eval do
          stateable do
            state :draft
            # Non definiamo :published
            transition :publish, from: :draft, to: :published
          end
        end
      end

      assert_match(/unknown state/i, error.message)
    end

    test "validates from state exists in transitions" do
      error = assert_raises(ArgumentError) do
        SecureStateable.class_eval do
          stateable do
            state :published
            # :draft non è mai stato definito
            transition :publish, from: :draft, to: :published
          end
        end
      end

      assert_match(/unknown state.*draft/i, error.message)
    end

    test "prevents duplicate state definitions" do
      error = assert_raises(ArgumentError) do
        SecureStateable.class_eval do
          stateable do
            state :draft
            state :draft # Duplicato
          end
        end
      end

      assert_match(/already defined/i, error.message)
    end

    test "prevents duplicate transition definitions" do
      error = assert_raises(ArgumentError) do
        SecureStateable.class_eval do
          stateable do
            state :draft
            state :published
            transition :publish, from: :draft, to: :published
            transition :publish, from: :draft, to: :published # Duplicato
          end
        end
      end

      assert_match(/already defined/i, error.message)
    end

    # ========================================
    # 3. PROTEZIONE METODI DINAMICI
    # ========================================

    test "state check methods are defined safely" do
      SecureStateable.class_eval do
        stateable do
          state :draft, initial: true
          state :published
        end
      end

      record = SecureStateable.create!

      # Metodi safe definiti automaticamente
      assert record.respond_to?(:draft?)
      assert record.respond_to?(:published?)
      assert record.draft?
      assert_not record.published?
    end

    test "transition methods work safely" do
      SecureStateable.class_eval do
        stateable do
          state :draft, initial: true
          state :published
          transition :publish, from: :draft, to: :published
        end
      end

      record = SecureStateable.create!

      # Metodo safe definito automaticamente
      assert record.respond_to?(:publish!)

      # Transizione valida
      assert record.publish!
      assert_equal "published", record.state
    end

    test "cannot call undefined transition methods" do
      SecureStateable.class_eval do
        stateable do
          state :draft, initial: true
        end
      end

      record = SecureStateable.new

      # Metodo non definito
      assert_raises(NoMethodError) do
        record.undefined_transition!
      end
    end

    # ========================================
    # 4. THREAD SAFETY
    # ========================================

    test "config is thread-safe after initialization" do
      SecureStateable.class_eval do
        stateable do
          state :draft
          state :published
        end
      end

      # Config dovrebbe essere identico in più thread
      results = 3.times.map do
        Thread.new { SecureStateable.stateable_states.object_id }
      end.map(&:value)

      # Tutti i thread dovrebbero vedere lo stesso oggetto frozen
      assert_equal 1, results.uniq.size
    end

    # ========================================
    # 5. CHECKS E VALIDAZIONI SICURE
    # ========================================

    test "checks are evaluated safely" do
      SecureStateable.class_eval do
        stateable do
          state :draft, initial: true
          state :published

          transition :publish, from: :draft, to: :published do
            check { title.present? }
          end
        end

        def title
          "Test Title"
        end
      end

      record = SecureStateable.create!

      # Check dovrebbe essere valutato nel contesto dell'istanza
      assert record.can_publish?
      assert record.publish!
    end

    test "transition validations work securely" do
      SecureStateable.class_eval do
        stateable do
          state :draft, initial: true
          state :published

          transition :publish, from: :draft, to: :published do
            validate { errors.add(:base, "Cannot publish") unless valid_for_publish? }
          end
        end

        def valid_for_publish?
          false
        end
      end

      record = SecureStateable.create!

      # Validazione dovrebbe impedire transizione (lanciando eccezione)
      assert_raises(BetterModel::Errors::Stateable::ValidationFailedError) do
        record.publish!
      end

      # Lo stato dovrebbe rimanere invariato
      assert_equal "draft", record.state
    end

    # ========================================
    # 6. CALLBACKS SICURI
    # ========================================

    test "before_transition callbacks execute safely" do
      _callback_executed = false

      SecureStateable.class_eval do
        stateable do
          state :draft, initial: true
          state :published

          transition :publish, from: :draft, to: :published do
            before_transition { @callback_flag = true }
          end
        end
      end

      record = SecureStateable.create!
      record.publish!

      # Callback dovrebbe essere eseguito
      assert record.instance_variable_get(:@callback_flag)
    end

    test "after_transition callbacks execute safely" do
      SecureStateable.class_eval do
        stateable do
          state :draft, initial: true
          state :published

          transition :publish, from: :draft, to: :published do
            after_transition { @after_flag = true }
          end
        end
      end

      record = SecureStateable.create!
      record.publish!

      # Callback dovrebbe essere eseguito dopo transizione
      assert record.instance_variable_get(:@after_flag)
      assert_equal "published", record.state
    end
  end
end
