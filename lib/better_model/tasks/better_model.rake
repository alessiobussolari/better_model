# frozen_string_literal: true

namespace :better_model do
  desc "Show BetterModel configuration"
  task config: :environment do
    puts "\n=== BetterModel Configuration ==="
    puts ""

    config = BetterModel.configuration

    puts "Searchable:"
    puts "  max_per_page:        #{config.searchable_max_per_page}"
    puts "  default_per_page:    #{config.searchable_default_per_page}"
    puts "  strict_predicates:   #{config.searchable_strict_predicates}"
    puts ""

    puts "Traceable:"
    puts "  default_table_name:  #{config.traceable_default_table_name || '(model-specific)'}"
    puts ""

    puts "Stateable:"
    puts "  default_table_name:  #{config.stateable_default_table_name}"
    puts ""

    puts "Archivable:"
    puts "  skip_archived_by_default: #{config.archivable_skip_archived_by_default}"
    puts ""

    puts "Global:"
    puts "  strict_mode:         #{config.strict_mode}"
    puts "  logger:              #{config.logger&.class&.name || 'nil'}"
    puts ""
  end

  desc "List all BetterModel modules"
  task modules: :environment do
    puts "\n=== BetterModel Modules ==="
    puts ""

    modules = %w[
      Archivable
      Permissible
      Predicable
      Repositable
      Searchable
      Sortable
      Stateable
      Statusable
      Taggable
      Traceable
      Validatable
    ]

    modules.each do |mod|
      status = defined?(BetterModel.const_get(mod)) ? "✓" : "✗"
      puts "  #{status} #{mod}"
    end

    puts ""
    puts "Total: #{modules.size} modules"
    puts ""
  end

  desc "Show BetterModel module usage in models"
  task models: :environment do
    puts "\n=== BetterModel Module Usage ==="
    puts ""

    # Eager load all models
    Rails.application.eager_load! if Rails.application.respond_to?(:eager_load!)

    models = ActiveRecord::Base.descendants.select do |model|
      model.included_modules.any? { |m| m.to_s.start_with?("BetterModel::") }
    end

    if models.empty?
      puts "No models using BetterModel modules found."
    else
      models.sort_by(&:name).each do |model|
        puts "#{model.name}:"

        better_model_modules = model.included_modules.select do |m|
          m.to_s.start_with?("BetterModel::") && !m.to_s.include?("Concerns")
        end

        better_model_modules.each do |mod|
          module_name = mod.to_s.split("::").last
          puts "  - #{module_name}"

          # Show module-specific info
          case module_name
          when "Searchable"
            if model.respond_to?(:searchable_predicates)
              puts "      predicates: #{model.searchable_predicates.size}"
            end
          when "Sortable"
            if model.respond_to?(:sortable_fields)
              puts "      sortable fields: #{model.sortable_fields.size}"
            end
          when "Stateable"
            if model.respond_to?(:state_machine_config) && model.state_machine_config
              puts "      states: #{model.state_machine_config.states.size}"
              puts "      events: #{model.state_machine_config.events.size}"
            end
          when "Traceable"
            if model.respond_to?(:traceable_enabled?) && model.traceable_enabled?
              puts "      enabled: true"
            end
          when "Taggable"
            if model.respond_to?(:taggable_enabled?) && model.taggable_enabled?
              puts "      enabled: true"
            end
          end
        end

        puts ""
      end

      puts "Total: #{models.size} models using BetterModel"
    end
    puts ""
  end

  desc "Show detailed info for a specific model (MODEL=ModelName)"
  task model_info: :environment do
    model_name = ENV["MODEL"]

    unless model_name
      puts "Usage: rake better_model:model_info MODEL=ModelName"
      exit 1
    end

    begin
      model = model_name.constantize
    rescue NameError
      puts "Model '#{model_name}' not found"
      exit 1
    end

    puts "\n=== #{model.name} BetterModel Info ==="
    puts ""

    # Searchable
    if model.respond_to?(:searchable_predicates)
      puts "Searchable Predicates:"
      model.searchable_predicates.each do |pred|
        puts "  - #{pred}"
      end
      puts ""
    end

    # Sortable
    if model.respond_to?(:sortable_fields) && model.sortable_fields.any?
      puts "Sortable Fields:"
      model.sortable_fields.each do |field|
        puts "  - #{field}"
      end

      if model.respond_to?(:sortable_scopes) && model.sortable_scopes.any?
        puts ""
        puts "Sortable Scopes:"
        model.sortable_scopes.each do |scope|
          puts "  - #{scope}"
        end
      end
      puts ""
    end

    # Stateable
    if model.respond_to?(:state_machine_config) && model.state_machine_config
      config = model.state_machine_config

      puts "State Machine:"
      puts "  Column: #{config.column}"
      puts "  Initial: #{config.initial_state}"
      puts ""

      puts "  States:"
      config.states.each do |state|
        puts "    - #{state}"
      end
      puts ""

      puts "  Events:"
      config.events.each do |event_name, event_config|
        puts "    - #{event_name}: #{event_config[:from].inspect} -> #{event_config[:to]}"
      end
      puts ""
    end

    # Traceable
    if model.respond_to?(:traceable_enabled?) && model.traceable_enabled?
      puts "Traceable:"
      puts "  Enabled: true"
      if model.respond_to?(:traceable_config) && model.traceable_config
        config = model.traceable_config
        puts "  Tracked fields: #{config.tracked_fields.join(', ')}" if config.respond_to?(:tracked_fields)
        puts "  Ignored fields: #{config.ignored_fields.join(', ')}" if config.respond_to?(:ignored_fields)
      end
      puts ""
    end

    # Taggable
    if model.respond_to?(:taggable_enabled?) && model.taggable_enabled?
      puts "Taggable:"
      puts "  Enabled: true"
      if model.respond_to?(:taggable_config) && model.taggable_config
        config = model.taggable_config
        puts "  Tag field: #{config.tag_field}"
        puts "  Normalize: #{config.normalize}"
      end
      puts ""
    end

    # Archivable
    if model.respond_to?(:archivable_enabled?) && model.archivable_enabled?
      puts "Archivable:"
      puts "  Enabled: true"
      if model.respond_to?(:archivable_config) && model.archivable_config
        config = model.archivable_config
        puts "  Column: #{config.column}"
      end
      puts ""
    end

    # Validatable
    if model.respond_to?(:validatable_enabled?) && model.validatable_enabled?
      puts "Validatable:"
      puts "  Enabled: true"
      if model.respond_to?(:validation_groups) && model.validation_groups.any?
        puts "  Groups: #{model.validation_groups.keys.join(', ')}"
      end
      puts ""
    end

    puts ""
  end

  desc "Check BetterModel health (database tables, etc.)"
  task health: :environment do
    puts "\n=== BetterModel Health Check ==="
    puts ""

    errors = []
    warnings = []

    # Check configuration
    config = BetterModel.configuration
    if config.strict_mode
      puts "✓ Strict mode is enabled"
    else
      warnings << "Strict mode is disabled (errors will be logged as warnings)"
    end

    if config.logger
      puts "✓ Logger is configured"
    else
      warnings << "No logger configured"
    end

    # Check for state_transitions table if any model uses Stateable
    Rails.application.eager_load! if Rails.application.respond_to?(:eager_load!)

    stateable_models = ActiveRecord::Base.descendants.select do |model|
      model.respond_to?(:state_machine_config) && model.state_machine_config
    end

    if stateable_models.any?
      table_name = config.stateable_default_table_name
      if ActiveRecord::Base.connection.table_exists?(table_name)
        puts "✓ State transitions table '#{table_name}' exists"
      else
        errors << "State transitions table '#{table_name}' does not exist (run migrations)"
      end
    end

    # Check for version tables if any model uses Traceable
    traceable_models = ActiveRecord::Base.descendants.select do |model|
      model.respond_to?(:traceable_enabled?) && model.traceable_enabled?
    end

    traceable_models.each do |model|
      if model.respond_to?(:versions_table_name)
        table_name = model.versions_table_name
        if ActiveRecord::Base.connection.table_exists?(table_name)
          puts "✓ Versions table '#{table_name}' exists for #{model.name}"
        else
          errors << "Versions table '#{table_name}' does not exist for #{model.name}"
        end
      end
    end

    puts ""

    if warnings.any?
      puts "Warnings:"
      warnings.each { |w| puts "  ⚠ #{w}" }
      puts ""
    end

    if errors.any?
      puts "Errors:"
      errors.each { |e| puts "  ✗ #{e}" }
      puts ""
      exit 1
    else
      puts "✓ All health checks passed"
      puts ""
    end
  end

  desc "Reset BetterModel configuration to defaults"
  task reset_config: :environment do
    BetterModel.reset_configuration!
    puts "BetterModel configuration has been reset to defaults."
  end

  namespace :stats do
    desc "Show tag statistics for taggable models"
    task tags: :environment do
      puts "\n=== BetterModel Tag Statistics ==="
      puts ""

      Rails.application.eager_load! if Rails.application.respond_to?(:eager_load!)

      taggable_models = ActiveRecord::Base.descendants.select do |model|
        model.respond_to?(:taggable_enabled?) && model.taggable_enabled?
      end

      if taggable_models.empty?
        puts "No taggable models found."
      else
        taggable_models.each do |model|
          puts "#{model.name}:"

          if model.respond_to?(:tag_counts)
            counts = model.tag_counts
            puts "  Total unique tags: #{counts.size}"

            if counts.any?
              top_5 = counts.sort_by { |_, v| -v }.first(5)
              puts "  Top 5 tags:"
              top_5.each do |tag, count|
                puts "    - #{tag}: #{count}"
              end
            end
          end

          puts ""
        end
      end
    end

    desc "Show state distribution for stateable models"
    task states: :environment do
      puts "\n=== BetterModel State Distribution ==="
      puts ""

      Rails.application.eager_load! if Rails.application.respond_to?(:eager_load!)

      stateable_models = ActiveRecord::Base.descendants.select do |model|
        model.respond_to?(:state_machine_config) && model.state_machine_config
      end

      if stateable_models.empty?
        puts "No stateable models found."
      else
        stateable_models.each do |model|
          config = model.state_machine_config
          column = config.column

          puts "#{model.name} (#{column}):"

          distribution = model.group(column).count
          total = distribution.values.sum

          config.states.each do |state|
            count = distribution[state.to_s] || 0
            percentage = total > 0 ? (count.to_f / total * 100).round(1) : 0
            bar = "█" * (percentage / 5).to_i
            puts "  #{state.to_s.ljust(15)} #{count.to_s.rjust(6)} (#{percentage.to_s.rjust(5)}%) #{bar}"
          end

          puts ""
        end
      end
    end

    desc "Show archive statistics for archivable models"
    task archives: :environment do
      puts "\n=== BetterModel Archive Statistics ==="
      puts ""

      Rails.application.eager_load! if Rails.application.respond_to?(:eager_load!)

      archivable_models = ActiveRecord::Base.descendants.select do |model|
        model.respond_to?(:archivable_enabled?) && model.archivable_enabled?
      end

      if archivable_models.empty?
        puts "No archivable models found."
      else
        archivable_models.each do |model|
          puts "#{model.name}:"

          total = model.unscoped.count
          archived = model.respond_to?(:archived) ? model.unscoped.archived.count : 0
          active = total - archived

          puts "  Total:    #{total}"
          puts "  Active:   #{active}"
          puts "  Archived: #{archived}"

          if total > 0
            percentage = (archived.to_f / total * 100).round(1)
            puts "  Archive rate: #{percentage}%"
          end

          puts ""
        end
      end
    end
  end
end
