# frozen_string_literal: true

module BetterModel
  # StateTransition - Base ActiveRecord model for state transition history
  #
  # Questo è un modello abstract. Le classi concrete vengono generate dinamicamente
  # per ogni tabella (state_transitions, order_transitions, etc.).
  #
  # Schema della tabella:
  #   t.string :transitionable_type, null: false
  #   t.integer :transitionable_id, null: false
  #   t.string :event, null: false
  #   t.string :from_state, null: false
  #   t.string :to_state, null: false
  #   t.json :metadata
  #   t.datetime :created_at, null: false
  #
  # Utilizzo:
  #   # Tutte le transizioni di un modello
  #   order.state_transitions
  #
  #   # Query globali (tramite classi dinamiche)
  #   BetterModel::StateTransitions.for_model(Order)
  #   BetterModel::OrderTransitions.by_event(:confirm)
  #
  class StateTransition < ActiveRecord::Base
    # Default table name (can be overridden by dynamic subclasses)
    self.table_name = "state_transitions"

    # Polymorphic association
    belongs_to :transitionable, polymorphic: true

    # Validations
    validates :event, :from_state, :to_state, presence: true

    # Scopes

    # Scope per modello specifico
    #
    # @param model_class [Class] Classe del modello
    # @return [ActiveRecord::Relation]
    #
    scope :for_model, ->(model_class) {
      where(transitionable_type: model_class.name)
    }

    # Scope per evento specifico
    #
    # @param event [Symbol, String] Nome dell'evento
    # @return [ActiveRecord::Relation]
    #
    scope :by_event, ->(event) {
      where(event: event.to_s)
    }

    # Scope per stato di partenza
    #
    # @param state [Symbol, String] Stato di partenza
    # @return [ActiveRecord::Relation]
    #
    scope :from_state, ->(state) {
      where(from_state: state.to_s)
    }

    # Scope per stato di arrivo
    #
    # @param state [Symbol, String] Stato di arrivo
    # @return [ActiveRecord::Relation]
    #
    scope :to_state, ->(state) {
      where(to_state: state.to_s)
    }

    # Scope per transizioni recenti
    #
    # @param duration [ActiveSupport::Duration] Durata (es. 7.days)
    # @return [ActiveRecord::Relation]
    #
    scope :recent, ->(duration = 7.days) {
      where("created_at >= ?", duration.ago)
    }

    # Scope per transizioni in un periodo
    #
    # @param start_time [Time, Date] Inizio periodo
    # @param end_time [Time, Date] Fine periodo
    # @return [ActiveRecord::Relation]
    #
    scope :between, ->(start_time, end_time) {
      where(created_at: start_time..end_time)
    }

    # Metodi di istanza

    # Formatted description della transizione
    #
    # @return [String]
    #
    def description
      "#{transitionable_type}##{transitionable_id}: #{from_state} -> #{to_state} (#{event})"
    end

    # Alias per retrocompatibilità
    alias_method :to_s, :description
  end
end
