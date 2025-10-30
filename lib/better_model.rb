require "better_model/version"
require "better_model/railtie"
require "better_model/statusable"
require "better_model/permissible"
require "better_model/sortable"
require "better_model/predicable"
require "better_model/searchable"
require "better_model/archivable"
require "better_model/version_record"
require "better_model/traceable"

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
    # Future concerns will be added here:
    # include BetterModel::Validatable
  end
end
