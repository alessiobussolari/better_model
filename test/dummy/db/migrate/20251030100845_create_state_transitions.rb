class CreateStateTransitions < ActiveRecord::Migration[8.1]
  def change
    create_table :state_transitions do |t|
      t.string :transitionable_type, null: false
      t.integer :transitionable_id, null: false
      t.string :event, null: false
      t.string :from_state, null: false
      t.string :to_state, null: false
      t.json :metadata

      t.datetime :created_at, null: false
    end

    add_index :state_transitions, [:transitionable_type, :transitionable_id], name: "index_state_transitions_on_transitionable"
    add_index :state_transitions, :event
    add_index :state_transitions, :from_state
    add_index :state_transitions, :to_state
    add_index :state_transitions, :created_at
  end
end
