require "better_model/version"
require "better_model/railtie"

# Load all error classes first
require "better_model/errors/better_model_error"
require "better_model/errors/archivable/archivable_error"
require "better_model/errors/archivable/already_archived_error"
require "better_model/errors/archivable/not_archived_error"
require "better_model/errors/archivable/not_enabled_error"
require "better_model/errors/validatable/validatable_error"
require "better_model/errors/validatable/not_enabled_error"
require "better_model/errors/traceable/traceable_error"
require "better_model/errors/traceable/not_enabled_error"
require "better_model/errors/searchable/searchable_error"
require "better_model/errors/searchable/invalid_predicate_error"
require "better_model/errors/searchable/invalid_order_error"
require "better_model/errors/searchable/invalid_pagination_error"
require "better_model/errors/searchable/invalid_security_error"
require "better_model/errors/stateable/stateable_error"
require "better_model/errors/stateable/not_enabled_error"
require "better_model/errors/stateable/invalid_state_error"
require "better_model/errors/stateable/invalid_transition_error"
require "better_model/errors/stateable/check_failed_error"
require "better_model/errors/stateable/validation_failed_error"
require "better_model/errors/stateable/configuration_error"
require "better_model/errors/archivable/configuration_error"
require "better_model/errors/validatable/configuration_error"
require "better_model/errors/traceable/configuration_error"
require "better_model/errors/searchable/configuration_error"
require "better_model/errors/predicable/predicable_error"
require "better_model/errors/predicable/configuration_error"
require "better_model/errors/sortable/sortable_error"
require "better_model/errors/sortable/configuration_error"
require "better_model/errors/statusable/statusable_error"
require "better_model/errors/statusable/configuration_error"
require "better_model/errors/permissible/permissible_error"
require "better_model/errors/permissible/configuration_error"
require "better_model/errors/taggable/taggable_error"
require "better_model/errors/taggable/configuration_error"

# Load shared concerns
require "better_model/concerns/enabled_check"
require "better_model/concerns/base_configurator"

# Load modules
require "better_model/statusable"
require "better_model/permissible"
require "better_model/sortable"
require "better_model/predicable"
require "better_model/searchable"
require "better_model/archivable"
require "better_model/models/version"
require "better_model/traceable"
require "better_model/validatable"
require "better_model/validatable/configurator"
require "better_model/models/state_transition"
require "better_model/stateable"
require "better_model/stateable/configurator"
require "better_model/stateable/guard"
require "better_model/stateable/transition"
require "better_model/taggable"
require "better_model/repositable"

module BetterModel
  extend ActiveSupport::Concern

  # When BetterModel is included, automatically include all sub-concerns
  included do
    include BetterModel::Statusable
    include BetterModel::Permissible
    include BetterModel::Sortable
    include BetterModel::Predicable
    include BetterModel::Searchable
    include BetterModel::Archivable
    include BetterModel::Traceable
    include BetterModel::Validatable
    include BetterModel::Stateable
    include BetterModel::Taggable
  end
end
