# frozen_string_literal: true

module BetterModel
  # Version model for tracking changes
  # This is the base AR model for version history
  # Actual table_name is set dynamically in subclasses
  class Version < ActiveRecord::Base
    self.abstract_class = true

    # Polymorphic association to the tracked model
    belongs_to :item, polymorphic: true, optional: true

    # Optional: belongs_to user who made the change
    # belongs_to :updated_by, class_name: "User", optional: true

    # Serialize object_changes as JSON
    # Rails handles this automatically for json/jsonb columns

    # Validations
    validates :item_type, :event, presence: true
    validates :event, inclusion: { in: %w[created updated destroyed] }

    # Scopes
    scope :for_item, ->(item) { where(item_type: item.class.name, item_id: item.id) }
    scope :created_events, -> { where(event: "created") }
    scope :updated_events, -> { where(event: "updated") }
    scope :destroyed_events, -> { where(event: "destroyed") }
    scope :by_user, ->(user_id) { where(updated_by_id: user_id) }
    scope :between, ->(start_time, end_time) { where(created_at: start_time..end_time) }
    scope :recent, ->(limit = 10) { order(created_at: :desc).limit(limit) }

    # Get the change for a specific field
    #
    # @param field_name [Symbol, String] Field name
    # @return [Hash, nil] Hash with :before and :after keys
    def change_for(field_name)
      return nil unless object_changes

      field = field_name.to_s
      return nil unless object_changes.key?(field)

      {
        before: object_changes[field][0],
        after: object_changes[field][1]
      }
    end

    # Check if a specific field changed in this version
    # This method overrides ActiveRecord's changed? to accept a field_name parameter
    #
    # @param field_name [Symbol, String, nil] Field name (if nil, calls ActiveRecord's changed?)
    # @return [Boolean]
    def changed?(field_name = nil)
      return super() if field_name.nil?

      object_changes&.key?(field_name.to_s) || false
    end

    # Get list of changed fields
    #
    # @return [Array<String>]
    def changed_fields
      object_changes&.keys || []
    end
  end
end
