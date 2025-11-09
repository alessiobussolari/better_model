# frozen_string_literal: true

module BetterModel
  module Models
    # StateTransition - Base ActiveRecord model for state transition history.
    #
    # This is an abstract model. Concrete classes are generated dynamically
    # for each table (state_transitions, order_transitions, etc.).
    #
    # @note Table Schema
    #   t.string :transitionable_type, null: false
    #   t.integer :transitionable_id, null: false
    #   t.string :event, null: false
    #   t.string :from_state, null: false
    #   t.string :to_state, null: false
    #   t.json :metadata
    #   t.datetime :created_at, null: false
    #
    # @example Usage
    #   # All transitions for a model
    #   order.state_transitions
    #
    # @example Global queries (via dynamic classes)
    #   BetterModel::Models::StateTransitions.for_model(Order)
    #   BetterModel::Models::OrderTransitions.by_event(:confirm)
    #
    class StateTransition < ActiveRecord::Base
      # Default table name (can be overridden by dynamic subclasses)
      self.table_name = "state_transitions"

      # Polymorphic association
      belongs_to :transitionable, polymorphic: true

      # Validations
      validates :event, :from_state, :to_state, presence: true

      # Scopes

      # Scope for specific model.
      #
      # @param model_class [Class] Model class
      # @return [ActiveRecord::Relation]
      #
      # @example
      #   StateTransition.for_model(Order)
      scope :for_model, ->(model_class) {
        where(transitionable_type: model_class.name)
      }

      # Scope for specific event.
      #
      # @param event [Symbol, String] Event name
      # @return [ActiveRecord::Relation]
      #
      # @example
      #   StateTransition.by_event(:confirm)
      scope :by_event, ->(event) {
        where(event: event.to_s)
      }

      # Scope for source state.
      #
      # @param state [Symbol, String] Source state
      # @return [ActiveRecord::Relation]
      #
      # @example
      #   StateTransition.from_state(:pending)
      scope :from_state, ->(state) {
        where(from_state: state.to_s)
      }

      # Scope for destination state.
      #
      # @param state [Symbol, String] Destination state
      # @return [ActiveRecord::Relation]
      #
      # @example
      #   StateTransition.to_state(:confirmed)
      scope :to_state, ->(state) {
        where(to_state: state.to_s)
      }

      # Scope for recent transitions.
      #
      # @param duration [ActiveSupport::Duration] Time duration (e.g., 7.days)
      # @return [ActiveRecord::Relation]
      #
      # @example
      #   StateTransition.recent(7.days)
      scope :recent, ->(duration = 7.days) {
        where("created_at >= ?", duration.ago)
      }

      # Scope for transitions in a time period.
      #
      # @param start_time [Time, Date] Period start
      # @param end_time [Time, Date] Period end
      # @return [ActiveRecord::Relation]
      #
      # @example
      #   StateTransition.between(1.week.ago, Time.current)
      scope :between, ->(start_time, end_time) {
        where(created_at: start_time..end_time)
      }

      # Instance Methods

      # Formatted description of the transition.
      #
      # @return [String] Human-readable transition description
      #
      # @example
      #   transition.description  # => "Order#123: pending -> confirmed (confirm)"
      def description
        "#{transitionable_type}##{transitionable_id}: #{from_state} -> #{to_state} (#{event})"
      end

      # Alias for backward compatibility
      alias_method :to_s, :description
    end
  end
end
