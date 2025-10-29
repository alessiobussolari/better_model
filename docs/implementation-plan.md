# Piano di Implementazione DSL per BetterModel

## Obiettivo

Implementare un sistema DSL modulare per migliorare la gestione dei modelli Rails con focus su:
- Riduzione del boilerplate
- Attributi tipizzati (estendendo ActiveModel::Attributes)
- Validazioni avanzate
- State machine (workflow con transizioni)
- Statusable (stati dichiarativi basati su condizioni)
- Searchable (sistema di ricerca e filtering avanzato)
- Concerns riutilizzabili

## Pattern Architetturali Utilizzati

1. **ActiveSupport::Concern** - Per modularità e clean module inclusion
2. **Registry Pattern** - Per gestione centralizzata dei tipi custom
3. **DSL Builder Classes** - Per sintassi DSL complesse e separazione delle responsabilità
4. **Class Methods via `class_methods do`** - Per definire metodi DSL a livello di classe
5. **Railtie + `ActiveSupport.on_load`** - Per integrazione lazy e sicura con Rails

## Struttura Directory Finale

```
lib/
├── better_model/
│   ├── version.rb
│   ├── railtie.rb
│   ├── configuration.rb
│   ├── statusable.rb              # Stati dichiarativi
│   ├── searchable.rb              # Sistema ricerca e filtering
│   ├── orderable.rb               # Sistema ordinamento
│   │
│   ├── attributes/
│   │   ├── base.rb
│   │   ├── type_registry.rb
│   │   └── types/
│   │       ├── email_type.rb
│   │       ├── url_type.rb
│   │       └── json_type.rb
│   │
│   ├── validations/
│   │   ├── base.rb
│   │   └── validators/
│   │       ├── email_validator.rb
│   │       └── url_validator.rb
│   │
│   ├── state_machine/
│   │   ├── base.rb
│   │   ├── dsl.rb
│   │   ├── transition.rb
│   │   └── state.rb
│   │
│   └── concerns/
│       └── (concerns riutilizzabili)
│
└── better_model.rb
```

---

## Fase 1: Setup Base

### 1.1 Aggiornare gemspec
**File:** `better_model.gemspec`

**Obiettivo:** Rimuovere placeholder TODO e aggiungere metadata validi

**Modifiche:**
```ruby
spec.homepage    = "https://github.com/alessiobussolari/better_model"
spec.summary     = "Enhanced DSL for Rails models"
spec.description = "BetterModel provides a set of DSL methods to reduce boilerplate in Rails models with typed attributes, advanced validations, and state machines."

spec.metadata["homepage_uri"] = spec.homepage
spec.metadata["source_code_uri"] = "https://github.com/alessiobussolari/better_model"
spec.metadata["changelog_uri"] = "https://github.com/alessiobussolari/better_model/blob/main/CHANGELOG.md"
```

### 1.2 Configuration System
**File:** `lib/better_model/configuration.rb`

**Obiettivo:** Sistema di configurazione globale per opzioni del gem

```ruby
# frozen_string_literal: true

module BetterModel
  class Configuration
    attr_accessor :default_state_column,
                  :state_machine_raise_on_invalid_transition,
                  :validation_errors_format

    def initialize
      @default_state_column = :state
      @state_machine_raise_on_invalid_transition = true
      @validation_errors_format = :detailed
    end
  end
end
```

**Utilizzo:**
```ruby
# config/initializers/better_model.rb
BetterModel.configure do |config|
  config.default_state_column = :status
  config.state_machine_raise_on_invalid_transition = false
end
```

### 1.3 Aggiornare Main Module
**File:** `lib/better_model.rb`

**Obiettivo:** Entry point con autoload e configurazione

```ruby
# frozen_string_literal: true

require "active_support"
require "active_model"
require "better_model/version"
require "better_model/configuration"
require "better_model/railtie" if defined?(Rails::Railtie)

module BetterModel
  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end

  # Autoload dei moduli
  autoload :Attributes, "better_model/attributes/base"
  autoload :Validations, "better_model/validations/base"
  autoload :StateMachine, "better_model/state_machine/base"
  autoload :Statusable, "better_model/statusable"
  autoload :Searchable, "better_model/searchable"
  autoload :Orderable, "better_model/orderable"
end
```

### 1.4 Migliorare Railtie
**File:** `lib/better_model/railtie.rb`

**Obiettivo:** Integrazione con Rails e registrazione tipi

```ruby
# frozen_string_literal: true

module BetterModel
  class Railtie < ::Rails::Railtie
    config.better_model = BetterModel.configuration

    config.eager_load_namespaces << BetterModel

    initializer "better_model.initialize" do
      ActiveSupport.on_load(:active_record) do
        # I moduli saranno disponibili per include manuale
      end
    end

    initializer "better_model.register_types", before: :set_autoload_paths do
      require "better_model/attributes/type_registry"
      BetterModel::Attributes::TypeRegistry.register_default_types
    end
  end
end
```

---

## Fase 2: Sistema Attributi Tipizzati

### 2.1 Base Concern
**File:** `lib/better_model/attributes/base.rb`

**Obiettivo:** Concern principale con DSL methods per attributi tipizzati

```ruby
# frozen_string_literal: true

require "active_support/concern"

module BetterModel
  module Attributes
    extend ActiveSupport::Concern

    included do
      unless respond_to?(:attribute)
        include ActiveModel::Attributes
      end
    end

    class_methods do
      # DSL method principale per attributi tipizzati
      def typed_attribute(name, type = :string, **options)
        resolved_type = BetterModel::Attributes::TypeRegistry.resolve(type)
        attribute(name, resolved_type, **options)
        define_typed_attribute_methods(name, type, options)
      end

      # Definisce più attributi dello stesso tipo
      def attributes_of_type(type, *names, **options)
        names.each do |name|
          typed_attribute(name, type, **options)
        end
      end

      # Shortcut per attributo email con validazione
      def email_attribute(name, **options)
        typed_attribute(name, :email, **options)
        validates name, format: { with: URI::MailTo::EMAIL_REGEXP },
                        allow_blank: options.fetch(:allow_blank, false)
      end

      # Attributo JSON con schema opzionale
      # Usa :better_json per evitare conflitto con il tipo nativo :json di Rails
      def json_attribute(name, schema: nil, **options)
        typed_attribute(name, :better_json, schema: schema, **options)
      end

      private

      def define_typed_attribute_methods(name, type, options)
        case type
        when :boolean
          define_boolean_attribute_methods(name)
        when :array
          define_array_attribute_methods(name)
        end
      end

      def define_boolean_attribute_methods(name)
        define_method("toggle_#{name}!") do
          self.send("#{name}=", !self.send(name))
          save! if persisted?
        end
      end

      def define_array_attribute_methods(name)
        define_method("add_to_#{name}") do |value|
          current = self.send(name) || []
          self.send("#{name}=", current + [value])
        end

        define_method("remove_from_#{name}") do |value|
          current = self.send(name) || []
          self.send("#{name}=", current - [value])
        end
      end
    end
  end
end
```

**Caratteristiche:**
- Estende `ActiveModel::Attributes`
- Supporto tipi custom via registry
- Generazione automatica helper methods
- Validazione integrata per tipi specifici (email)

### 2.2 Type Registry
**File:** `lib/better_model/attributes/type_registry.rb`

**Obiettivo:** Registry centralizzato per tipi custom

```ruby
# frozen_string_literal: true

require "active_model/type"

module BetterModel
  module Attributes
    class TypeRegistry
      class << self
        def registry
          @registry ||= {}
        end

        # Registra un tipo custom
        def register(name, type_class = nil, &block)
          type = type_class || block
          registry[name.to_sym] = type

          if type_class && type_class < ActiveModel::Type::Value
            ActiveModel::Type.register(name, type_class)
          end
        end

        # Risolve un tipo (custom o standard)
        def resolve(type)
          case type
          when Symbol
            registry[type] || type
          when Class
            type
          else
            type
          end
        end

        # Registra tipi built-in
        def register_default_types
          require "better_model/attributes/types/email_type"
          require "better_model/attributes/types/url_type"
          require "better_model/attributes/types/json_type"

          register(:email, BetterModel::Attributes::Types::EmailType)
          register(:url, BetterModel::Attributes::Types::UrlType)
          # NOTA: Rinominato da :json a :better_json per evitare conflitto
          # con il tipo nativo :json di Rails (specialmente PostgreSQL)
          register(:better_json, BetterModel::Attributes::Types::JsonType)
        end
      end
    end
  end
end
```

### 2.3 Custom Types

#### Email Type
**File:** `lib/better_model/attributes/types/email_type.rb`

```ruby
# frozen_string_literal: true

require "active_model/type"

module BetterModel
  module Attributes
    module Types
      class EmailType < ActiveModel::Type::String
        def cast(value)
          value = super
          value&.strip&.downcase
        end

        def serialize(value)
          cast(value)
        end
      end
    end
  end
end
```

#### URL Type
**File:** `lib/better_model/attributes/types/url_type.rb`

```ruby
# frozen_string_literal: true

require "active_model/type"
require "uri"

module BetterModel
  module Attributes
    module Types
      class UrlType < ActiveModel::Type::String
        def cast(value)
          value = super
          return nil if value.blank?

          begin
            uri = URI.parse(value)
            uri.to_s
          rescue URI::InvalidURIError
            value
          end
        end

        def serialize(value)
          cast(value)
        end
      end
    end
  end
end
```

#### JSON Type
**File:** `lib/better_model/attributes/types/json_type.rb`

```ruby
# frozen_string_literal: true

require "active_model/type"
require "json"

module BetterModel
  module Attributes
    module Types
      class JsonType < ActiveModel::Type::Value
        def type
          :json
        end

        def cast(value)
          case value
          when String
            JSON.parse(value) rescue {}
          when Hash, Array
            value
          else
            {}
          end
        end

        def serialize(value)
          JSON.generate(value) if value.present?
        end

        def deserialize(value)
          case value
          when String
            JSON.parse(value) rescue {}
          else
            value
          end
        end
      end
    end
  end
end
```

---

## Fase 3: Validazioni Avanzate

### 3.1 Base Concern
**File:** `lib/better_model/validations/base.rb`

**Obiettivo:** DSL methods per validazioni espressive

```ruby
# frozen_string_literal: true

require "active_support/concern"

module BetterModel
  module Validations
    extend ActiveSupport::Concern

    included do
      unless respond_to?(:validates)
        include ActiveModel::Validations
      end
    end

    class_methods do
      # Alias espressivo per presence validation
      def required(*attributes, message: nil)
        options = message ? { message: message } : {}
        validates(*attributes, presence: true, **options)
      end

      # Applica stesse validazioni a più attributi
      def validate_all(*attributes, **rules)
        validates(*attributes, **rules)
      end

      # Email validation DSL
      def validates_email(*attributes, **options)
        validates(*attributes,
          format: { with: URI::MailTo::EMAIL_REGEXP },
          **options
        )
      end

      # URL validation DSL
      def validates_url(*attributes, **options)
        require "better_model/validations/validators/url_validator"
        validates(*attributes, url: true, **options)
      end

      # Gruppi di validazioni per contesto
      def validates_on(context, &block)
        validation_context = ValidationContext.new(self, context)
        validation_context.instance_eval(&block)
      end

      # Custom validation con block
      def validates_with_rule(attribute, &block)
        validate do
          result = instance_eval(&block)
          errors.add(attribute, "is invalid") unless result
        end
      end
    end

    # Helper class per validation contexts
    class ValidationContext
      def initialize(model_class, context)
        @model_class = model_class
        @context = context
      end

      def validates(*args, **kwargs)
        @model_class.validates(*args, **kwargs.merge(on: @context))
      end

      def required(*args, **kwargs)
        @model_class.required(*args, **kwargs.merge(on: @context))
      end

      def validates_email(*args, **kwargs)
        @model_class.validates_email(*args, **kwargs.merge(on: @context))
      end

      def validates_url(*args, **kwargs)
        @model_class.validates_url(*args, **kwargs.merge(on: @context))
      end
    end
  end
end
```

### 3.2 Custom Validators

#### Email Validator
**File:** `lib/better_model/validations/validators/email_validator.rb`

```ruby
# frozen_string_literal: true

require "active_model/validator"

module BetterModel
  module Validations
    class EmailValidator < ActiveModel::EachValidator
      def validate_each(record, attribute, value)
        return if value.blank? && options[:allow_blank]

        unless value =~ URI::MailTo::EMAIL_REGEXP
          record.errors.add(attribute, options[:message] || "is not a valid email address")
        end
      end
    end
  end
end
```

#### URL Validator
**File:** `lib/better_model/validations/validators/url_validator.rb`

```ruby
# frozen_string_literal: true

require "active_model/validator"
require "uri"

module BetterModel
  module Validations
    class UrlValidator < ActiveModel::EachValidator
      def validate_each(record, attribute, value)
        return if value.blank? && options[:allow_blank]

        begin
          uri = URI.parse(value)
          unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
            record.errors.add(attribute, options[:message] || "is not a valid URL")
          end
        rescue URI::InvalidURIError
          record.errors.add(attribute, options[:message] || "is not a valid URL")
        end
      end
    end
  end
end
```

---

## Fase 4: State Machine

### 4.1 Base Concern
**File:** `lib/better_model/state_machine/base.rb`

**Obiettivo:** Concern principale per state machines

```ruby
# frozen_string_literal: true

require "active_support/concern"
require "better_model/state_machine/dsl"
require "better_model/state_machine/transition"

module BetterModel
  module StateMachine
    extend ActiveSupport::Concern

    included do
      class_attribute :state_machines, default: {}

      if respond_to?(:before_save)
        before_save :track_state_changes
      end
    end

    class_methods do
      # DSL entry point
      def state_machine(column = nil, &block)
        column ||= BetterModel.configuration.default_state_column

        machine = StateMachineDSL.new(self, column)
        machine.instance_eval(&block)

        self.state_machines = state_machines.merge(column => machine)

        define_state_machine_methods(column, machine)
      end

      private

      def define_state_machine_methods(column, machine)
        # State query methods usando pattern in_* per evitare conflitti
        # (e.g., in_draft?, in_published?)
        machine.states.each do |state|
          # Verifica stato corrente: in_#{state}?
          define_method("in_#{state}?") do
            send(column).to_s == state.to_s
          end

          # Verifica stato precedente: was_#{state}?
          # Usa Rails' #{column}_was da ActiveRecord::Dirty
          define_method("was_#{state}?") do
            send("#{column}_was").to_s == state.to_s
          end
        end

        # Transition methods usando pattern to_* per focus sullo stato destinazione
        # Genera metodi basati sullo stato TO, non sul nome transizione
        # (e.g., to_published!, to_archived!)
        machine.transitions.each do |transition|
          to_state = transition.to

          # Metodo di transizione: to_#{state}!
          define_method("to_#{to_state}!") do
            transition.execute(self, column)
          end

          # Verifica se transizione è possibile: can_to_#{state}?
          define_method("can_to_#{to_state}?") do
            transition.can_execute?(self, column)
          end
        end

        # State accessor (mantiene current_#{column} per accesso diretto)
        define_method("current_#{column}") do
          send(column)
        end
      end
    end

    # Instance methods
    def track_state_changes
      state_machines.each do |column, _machine|
        if send("#{column}_changed?")
          @state_transitions ||= {}
          @state_transitions[column] = {
            from: send("#{column}_was"),
            to: send(column)
          }
        end
      end
    end

    def state_transition(column = :state)
      @state_transitions&.dig(column)
    end
  end
end
```

### 4.2 DSL Builder
**File:** `lib/better_model/state_machine/dsl.rb`

**Obiettivo:** Builder class per definire stati e transizioni

```ruby
# frozen_string_literal: true

module BetterModel
  module StateMachine
    class StateMachineDSL
      attr_reader :states, :transitions, :model_class, :column

      def initialize(model_class, column)
        @model_class = model_class
        @column = column
        @states = []
        @transitions = []
        @initial_state = nil
      end

      # Definisce gli stati disponibili
      def states(*state_names)
        @states.concat(state_names.map(&:to_sym))
      end

      # Definisce lo stato iniziale
      def initial(state_name)
        @initial_state = state_name.to_sym
        @states << @initial_state unless @states.include?(@initial_state)

        # Capture initial_state in a local variable for closure
        # This ensures the value is accessible inside the after_initialize callback
        initial_state_value = @initial_state
        state_column = column

        model_class.after_initialize do
          if send(state_column).nil?
            send("#{state_column}=", initial_state_value)
          end
        end
      end

      # Definisce una transizione
      def transition(name, from:, to:, if: nil, unless: nil, after: nil, before: nil)
        trans = Transition.new(
          name: name,
          from: Array(from),
          to: to,
          if_condition: binding.local_variable_get(:if),
          unless_condition: binding.local_variable_get(:unless),
          after_callback: after,
          before_callback: before
        )
        @transitions << trans
      end

      # Sintassi alternativa event-based
      def event(name, &block)
        event_dsl = EventDSL.new(name)
        event_dsl.instance_eval(&block)

        event_dsl.transitions.each do |trans_def|
          transition(
            name,
            from: trans_def[:from],
            to: trans_def[:to],
            if: trans_def[:if],
            unless: trans_def[:unless],
            after: trans_def[:after],
            before: trans_def[:before]
          )
        end
      end
    end

    class EventDSL
      attr_reader :name, :transitions

      def initialize(name)
        @name = name
        @transitions = []
      end

      def transition(from:, to:, **options)
        @transitions << { from: from, to: to, **options }
      end
    end
  end
end
```

### 4.3 Transition Class
**File:** `lib/better_model/state_machine/transition.rb`

**Obiettivo:** Classe per gestire transizioni e callbacks

```ruby
# frozen_string_literal: true

module BetterModel
  module StateMachine
    class Transition
      attr_reader :name, :from, :to, :if_condition, :unless_condition,
                  :after_callback, :before_callback

      def initialize(name:, from:, to:, if_condition: nil, unless_condition: nil,
                     after_callback: nil, before_callback: nil)
        @name = name
        @from = from
        @to = to
        @if_condition = if_condition
        @unless_condition = unless_condition
        @after_callback = after_callback
        @before_callback = before_callback
      end

      def can_execute?(record, column)
        current_state = record.send(column).to_sym

        return false unless from.include?(current_state)

        if if_condition
          return false unless evaluate_condition(record, if_condition)
        end

        if unless_condition
          return false if evaluate_condition(record, unless_condition)
        end

        true
      end

      def execute(record, column)
        unless can_execute?(record, column)
          raise_invalid_transition_error(record, column)
        end

        # Wrap transition in transaction for data consistency
        # If after_callback fails, the entire transition is rolled back
        if record.class.respond_to?(:transaction)
          record.class.transaction do
            perform_transition(record, column)
          end
        else
          # Fallback for non-ActiveRecord models
          perform_transition(record, column)
        end

        true
      end

      private

      def perform_transition(record, column)
        execute_callback(record, before_callback) if before_callback

        record.send("#{column}=", to)

        if record.respond_to?(:save!)
          record.save!
        end

        execute_callback(record, after_callback) if after_callback
      end

      def evaluate_condition(record, condition)
        case condition
        when Symbol
          record.send(condition)
        when Proc
          record.instance_exec(&condition)
        else
          raise ArgumentError, "Invalid condition type: #{condition.class}"
        end
      end

      def execute_callback(record, callback)
        case callback
        when Symbol
          record.send(callback)
        when Proc
          record.instance_exec(&callback)
        end
      end

      def raise_invalid_transition_error(record, column)
        current = record.send(column)
        message = "Cannot transition from #{current} to #{to} via #{name}"

        if BetterModel.configuration.state_machine_raise_on_invalid_transition
          raise InvalidTransitionError, message
        else
          record.errors.add(column, message)
          false
        end
      end
    end

    class InvalidTransitionError < StandardError; end
  end
end
```

### 4.4 State Class (opzionale)
**File:** `lib/better_model/state_machine/state.rb`

```ruby
# frozen_string_literal: true

module BetterModel
  module StateMachine
    class State
      attr_reader :name, :options

      def initialize(name, **options)
        @name = name.to_sym
        @options = options
      end

      def ==(other)
        case other
        when State
          name == other.name
        when Symbol, String
          name == other.to_sym
        else
          false
        end
      end
    end
  end
end
```

### 4.4.1 Callback Execution Order - IMPORTANTE

**Ordine di Esecuzione durante una Transizione:**

Quando si chiama un metodo di transizione (es. `article.to_published!`), l'ordine di esecuzione è il seguente:

```
1. StateMachine before_callback (se definito)
   ↓
2. Cambio dello stato (article.status = :published)
   ↓
3. ActiveRecord before_save callbacks
   ↓
4. ActiveRecord before_validation callbacks
   ↓
5. Validazioni ActiveRecord
   ↓
6. ActiveRecord after_validation callbacks
   ↓
7. Scrittura nel database (SQL INSERT/UPDATE)
   ↓
8. ActiveRecord after_save callbacks
   ↓
9. ActiveRecord after_commit callbacks
   ↓
10. StateMachine after_callback (se definito)
```

**Nota Critica:** I callback `before` e `after` di StateMachine sono **diversi** dai callback ActiveRecord:

- **`before: :my_method`** (StateMachine) → Eseguito PRIMA di before_save
- **`after: :my_method`** (StateMachine) → Eseguito DOPO after_commit
- **`before_save :my_method`** (ActiveRecord) → Eseguito durante il salvataggio

**Transazioni e Rollback:**

Tutte le operazioni (step 1-10) sono wrappate in una **transazione database**. Se qualsiasi step fallisce:
- La transazione viene rollback
- Lo stato NON viene salvato nel database
- L'eccezione viene propagata (o `false` viene ritornato se configurato)

**Esempio Pratico:**

```ruby
class Article < ApplicationRecord
  include BetterModel::StateMachine

  # ActiveRecord callbacks
  before_save :log_before_save
  after_save :log_after_save
  after_commit :notify_subscribers

  # State Machine
  state_machine :status do
    states :draft, :published

    transition :publish,
      from: :draft,
      to: :published,
      before: :prepare_for_publication,    # Step 1
      after: :announce_publication         # Step 10
  end

  private

  def prepare_for_publication
    puts "1. StateMachine before_callback"
    self.published_at = Time.current
  end

  def log_before_save
    puts "3. ActiveRecord before_save"
  end

  def log_after_save
    puts "8. ActiveRecord after_save"
  end

  def notify_subscribers
    puts "9. ActiveRecord after_commit"
  end

  def announce_publication
    puts "10. StateMachine after_callback"
    # A questo punto il record è già salvato e committed nel database
    # Sicuro per operazioni esterne (API calls, email, background jobs)
  end
end

# Output quando si chiama article.to_published!:
# 1. StateMachine before_callback
# 3. ActiveRecord before_save
# (validations...)
# (SQL UPDATE...)
# 8. ActiveRecord after_save
# 9. ActiveRecord after_commit
# 10. StateMachine after_callback
```

**Best Practices:**

1. **Before Callback**: Usa per preparare dati, validazioni custom, modifiche allo stato
2. **After Callback**: Usa per notifiche esterne, background jobs, API calls
3. **Operazioni idempotenti**: Gli after_callback dovrebbero essere idempotenti (possono essere eseguiti più volte senza problemi)
4. **Gestione errori**: Se after_callback fallisce, lo stato è GIÀ nel database (grazie alla transazione). Implementa retry logic se necessario.

---

## Fase 4.5: Statusable - Stati Dichiarativi

### 4.5.1 Differenza tra StateMachine e Statusable

**StateMachine** (Fase 4):
- Workflow con **transizioni esplicite** tra stati
- Stati memorizzati nel database (colonna `status`, `state`, etc.)
- Transizioni controllate tramite metodi (`publish!`, `archive!`)
- Callbacks durante le transizioni
- Esempio: `draft → in_review → published → archived`

**Statusable** (Fase 4.5):
- Stati **derivati da condizioni** calcolate dinamicamente
- Non memorizzati nel database, ma calcolati al volo
- Query dichiarative basate su lambda/proc
- Nessuna transizione esplicita
- Esempio: `is_expired?`, `is_ready_to_start?`, `is_active?`

**Uso combinato**: StateMachine gestisce il workflow principale (stato persistente), mentre Statusable fornisce stati derivati per query complesse.

### 4.5.2 Concern Statusable
**File:** `lib/better_model/statusable.rb`

**Obiettivo:** Sistema di stati dichiarativi basati su condizioni

```ruby
# frozen_string_literal: true

# Statusable - Sistema di stati dichiarativi per modelli Rails
#
# Questo concern permette di definire stati sui modelli utilizzando un DSL
# semplice e dichiarativo, per query di stati basate su condizioni complesse.
#
# Esempio di utilizzo:
#   class Consult < ApplicationRecord
#     include BetterModel::Statusable
#
#     is :pending, -> { status == 'initialized' }
#     is :active_session, -> { status == 'active' && !expired? }
#     is :expired, -> { expires_at.present? && expires_at <= Time.current }
#     is :scheduled, -> { scheduled_at.present? }
#     is :immediate, -> { scheduled_at.blank? }
#     is :ready_to_start, -> { scheduled? && scheduled_at <= Time.current }
#   end
#
# Utilizzo:
#   consult.is?(:pending)           # => true/false
#   consult.is_pending?             # => true/false
#   consult.is_active_session?      # => true/false
#   consult.is_expired?             # => true/false
#   consult.status_checks           # => { pending: true, expired: false, ... }
#
module BetterModel
  module Statusable
    extend ActiveSupport::Concern

    included do
      # Registry degli stati definiti per questa classe
      class_attribute :is_definitions
      self.is_definitions = {}
    end

    class_methods do
      # DSL per definire stati
      #
      # Parametri:
      # - status_name: simbolo che rappresenta lo stato (es. :pending, :active)
      # - condition_proc: lambda o proc che definisce la condizione
      # - block: blocco alternativo alla condition_proc
      #
      # Esempi:
      #   is :pending, -> { status == 'initialized' }
      #   is :expired, -> { expires_at.present? && expires_at <= Time.current }
      #   is :ready do
      #     scheduled_at.present? && scheduled_at <= Time.current
      #   end
      def is(status_name, condition_proc = nil, &block)
        # Valida i parametri prima di convertire
        raise ArgumentError, 'Status name cannot be blank' if status_name.blank?

        status_name = status_name.to_sym
        condition = condition_proc || block
        raise ArgumentError, 'Condition proc or block is required' unless condition
        raise ArgumentError, 'Condition must respond to call' unless condition.respond_to?(:call)

        # Registra lo stato nel registry
        self.is_definitions = is_definitions.merge(status_name => condition.freeze).freeze

        # Genera il metodo dinamico is_#{status_name}?
        define_is_method(status_name)
      end

      # Lista di tutti gli stati definiti per questa classe
      def defined_statuses
        is_definitions.keys
      end

      # Verifica se uno stato è definito
      def status_defined?(status_name)
        is_definitions.key?(status_name.to_sym)
      end

      private

      # Genera dinamicamente il metodo is_#{status_name}? per ogni stato definito
      def define_is_method(status_name)
        method_name = "is_#{status_name}?"

        # Evita di ridefinire metodi se già esistono
        return if method_defined?(method_name)

        define_method(method_name) do
          is?(status_name)
        end
      end
    end

    # Metodo generico per verificare se uno stato è attivo
    #
    # Parametri:
    # - status_name: simbolo dello stato da verificare
    #
    # Ritorna:
    # - true se lo stato è attivo
    # - false se lo stato non è attivo o non è definito
    #
    # Esempio:
    #   consult.is?(:pending)
    def is?(status_name)
      status_name = status_name.to_sym
      condition = self.class.is_definitions[status_name]

      # Se lo stato non è definito, ritorna false (secure by default)
      return false unless condition

      # Valuta la condizione nel contesto dell'istanza del modello
      instance_exec(&condition)
    end

    # Ritorna tutti gli stati disponibili per questa istanza con i loro valori
    #
    # NOTA: Rinominato da 'statuses' a 'status_checks' per evitare conflitto
    # con Rails' enum feature che genera automaticamente un metodo 'statuses'
    # quando si usa: enum status: [:draft, :published]
    #
    # Ritorna:
    # - Hash con chiavi simbolo (stati) e valori booleani (attivi/inattivi)
    #
    # Esempio:
    #   consult.status_checks
    #   # => { pending: true, active: false, expired: false, scheduled: true }
    def status_checks
      self.class.is_definitions.each_with_object({}) do |(status_name, _condition), result|
        result[status_name] = is?(status_name)
      end
    end

    # Verifica se l'istanza ha almeno uno stato attivo
    def has_any_status?
      status_checks.values.any?
    end

    # Verifica se l'istanza ha tutti gli stati specificati attivi
    def has_all_statuses?(status_names)
      Array(status_names).all? { |status_name| is?(status_name) }
    end

    # Filtra una lista di stati restituendo solo quelli attivi
    def active_statuses(status_names)
      Array(status_names).select { |status_name| is?(status_name) }
    end

    # Override di as_json per includere automaticamente gli stati se richiesto
    def as_json(options = {})
      result = super

      # Include gli stati se esplicitamente richiesto
      if options[:include_statuses]
        result['status_checks'] = status_checks.transform_keys(&:to_s)
      end

      result
    end
  end
end
```

**Caratteristiche:**
- Stati calcolati dinamicamente basati su condizioni
- Registry pattern per gestire definizioni
- Generazione automatica metodi `is_#{status}?`
- Metodi helper per query su stati multipli
- Integrazione con `as_json` per serializzazione

### 4.5.3 Esempio di Uso Combinato: StateMachine + Statusable

```ruby
class Consult < ApplicationRecord
  include BetterModel::StateMachine
  include BetterModel::Statusable

  # StateMachine per workflow principale (stato persistente)
  state_machine :status do
    initial :initialized

    states :initialized, :active, :completed, :cancelled

    transition :start, from: :initialized, to: :active,
               if: :ready_to_start?

    transition :complete, from: :active, to: :completed
    transition :cancel, from: [:initialized, :active], to: :cancelled
  end

  # Statusable per stati derivati (query complesse)
  is :pending, -> { status == 'initialized' }
  is :active_session, -> { status == 'active' && !expired? }
  is :expired, -> { expires_at.present? && expires_at <= Time.current }
  is :scheduled, -> { scheduled_at.present? }
  is :immediate, -> { scheduled_at.blank? }
  is :ready_to_start, -> {
    scheduled? &&
    scheduled_at <= Time.current &&
    !expired?
  }
  is :can_be_started, -> {
    pending? &&
    ready_to_start? &&
    !expired?
  }

  private

  def ready_to_start?
    is?(:ready_to_start)
  end
end

# Uso:
consult = Consult.create(
  status: 'initialized',
  scheduled_at: 5.minutes.from_now,
  expires_at: 1.hour.from_now
)

# Stati da StateMachine (persistenti)
consult.initialized?              # => true
consult.can_start?                # => false (scheduled_at non ancora raggiunto)

# Stati da Statusable (derivati)
consult.is_pending?               # => true
consult.is_scheduled?             # => true
consult.is_immediate?             # => false
consult.is_ready_to_start?        # => false (scheduled_at non ancora raggiunto)
consult.is_expired?               # => false

# Dopo 5 minuti...
consult.is_ready_to_start?        # => true
consult.can_start?                # => true
consult.start!                    # => transizione a :active

consult.active?                   # => true (StateMachine)
consult.is_active_session?        # => true (Statusable)

# Query su stati multipli
consult.status_checks
# => { pending: false, active_session: true, expired: false, ... }

# Serializzazione con stati
consult.as_json(include_statuses: true)
# => { "id" => 1, "status" => "active", "status_checks" => { "pending" => false, ... } }
```

---

## Fase 4.6: Searchable - Sistema di Ricerca e Filtering

### 4.6.1 Panoramica

**Searchable** fornisce un sistema completo di ricerca e filtering per modelli ActiveRecord, progettato come sostituto di Ransack/Searchkick con focus su:
- Generazione automatica di predicati basati sul tipo di colonna
- API di ricerca unificata tramite `search(predicates)`
- Registry per predicati complessi custom
- Sicurezza SQL tramite Arel
- Zero dipendenze esterne

**Filosofia**: Ridurre drasticamente il boilerplate definendo automaticamente scope di ricerca intelligenti basati sui tipi di colonna del modello.

### 4.6.2 Concern Searchable
**File:** `lib/better_model/searchable.rb`

**Obiettivo:** Sistema di ricerca enterprise-grade con predicati auto-generati

```ruby
# frozen_string_literal: true

module BetterModel
  module Searchable
    extend ActiveSupport::Concern

    # Custom exception for missing required predicates
    class RequiredPredicateError < ArgumentError
      attr_reader :scope, :missing_predicates

      def initialize(scope, missing_predicates)
        @scope = scope
        @missing_predicates = missing_predicates
        super("Required predicates missing for scope '#{scope}': #{missing_predicates.join(', ')}")
      end
    end

    included do
      # Validate that the including class is an ActiveRecord model
      # Searchable requires ActiveRecord-specific features (arel_table, where, scope, etc.)
      unless ancestors.include?(ActiveRecord::Base)
        raise ArgumentError, "BetterModel::Searchable can only be included in ActiveRecord models. " \
                             "The class #{name} does not inherit from ActiveRecord::Base."
      end

      # Registry per predicati complessi
      class_attribute :complex_predicates_registry, default: {}

      # Registry for required predicates by scope (multitenancy security)
      class_attribute :required_predicates_by_scope, default: {}

      # Scope base comuni a tutti i modelli
      scope :id_in, ->(ids) { where(id: ids) if ids.present? }
      scope :created_at_between, lambda { |start_date, end_date|
        where(created_at: start_date..end_date) if start_date.present? && end_date.present?
      }
      scope :updated_at_between, lambda { |start_date, end_date|
        where(updated_at: start_date..end_date) if start_date.present? && end_date.present?
      }
    end

    class_methods do
      # Registra un predicato complesso con query custom
      def register_complex_predicate(name, &block)
        # Salva il block nel registry
        self.complex_predicates_registry = complex_predicates_registry.merge(name.to_sym => block)

        # Crea scope dinamico che usa il registry
        scope name, lambda { |*args|
          return all if args.empty? || args.all?(&:blank?)

          registry_block = complex_predicates_registry[name.to_sym]
          registry_block ? registry_block.call(self, *args) : all
        }
      end

      # Define required predicates for a specific scope
      # @param scope_name [Symbol] The scope identifier
      # @param predicates [Array<Symbol>] List of required predicate names
      # @example
      #   require_predicates_for_scope :doctor_dashboard, :doctor_id_eq, :organization_id_eq
      def require_predicates_for_scope(scope_name, *predicates)
        self.required_predicates_by_scope =
          required_predicates_by_scope.merge(
            scope_name.to_sym => predicates.map(&:to_sym)
          )
      end

      # Metodo search avanzato con predicates e opzioni
      def search(predicates = {}, page: 1, per_page: 20, includes: [], joins: [],
                 order: nil, limit: :default, scope: :default)
        # Rimuovi valori nil (mantieni false per predicati booleani)
        cleaned_predicates = predicates.compact

        # Valida che i predicati siano supportati dal modello
        validate_predicates!(cleaned_predicates) if cleaned_predicates.present?

        # Validate required predicates for non-default scopes (multitenancy security)
        validate_required_predicates!(cleaned_predicates, scope) if scope != :default

        # Applica predicati di ricerca
        result = if cleaned_predicates.present?
                   advanced_search(cleaned_predicates)
                 else
                   all
                 end

        # Applica joins PRIMA di includes (necessario per ORDER BY su joined tables)
        result = result.joins(*joins) if joins.present?

        # Applica includes se specificati
        result = result.includes(*includes) if includes.present?

        # Applica ordinamento se specificato
        result = apply_ordering(result, order) if order.present?

        # Applica limit se specificato (ha priorità sulla paginazione)
        case limit
        when 1
          result.first
        when (2..)
          result.limit(limit)
        when nil
          # limit: nil explicitly means unlimited - return all results
          result
        when :default
          # :default means use pagination (this is the default when no limit is specified)
          paginate(result, page: page, per_page: per_page)
        else
          # Fallback to pagination for any other case
          paginate(result, page: page, per_page: per_page)
        end
      end

      # Sistema search interno con predicates
      def advanced_search(predicates = {})
        result = all

        # Applica dinamicamente TUTTI i predicati disponibili
        predicates.each do |predicate_name, value|
          next if value.nil?

          result = result.public_send(predicate_name, value) if result.respond_to?(predicate_name)
        end

        result
      end

      # Apply ordering with support for multiple formats
      # @param relation [ActiveRecord::Relation] The relation to order
      # @param order_value [Symbol, String, Hash, Array] The ordering specification
      # @return [ActiveRecord::Relation] The ordered relation
      def apply_ordering(relation, order_value)
        case order_value
        when Symbol, String
          # Single Orderable scope: :published_at_newest
          apply_scope_ordering(relation, order_value.to_sym)

        when Hash
          # Rails order hash: { published_at: :desc, view_count: :asc }
          apply_rails_ordering(relation, order_value)

        when Array
          # Mixed array: [:published_at_newest, { view_count: :desc }]
          order_value.reduce(relation) { |rel, item| apply_ordering(rel, item) }

        else
          Rails.logger.warn "[BetterModel::Searchable] Unknown order format: #{order_value.class}"
          relation
        end
      end

      # Apply Orderable scope ordering
      # @param relation [ActiveRecord::Relation] The relation to order
      # @param scope_name [Symbol] The Orderable scope name
      # @return [ActiveRecord::Relation] The ordered relation
      def apply_scope_ordering(relation, scope_name)
        if is_orderable_scope?(scope_name) && relation.respond_to?(scope_name)
          relation.send(scope_name)
        else
          Rails.logger.warn "[BetterModel::Searchable] Unknown or unregistered Orderable scope: #{scope_name}"
          relation
        end
      end

      # Apply standard Rails ordering
      # @param relation [ActiveRecord::Relation] The relation to order
      # @param order_hash [Hash] The Rails order hash
      # @return [ActiveRecord::Relation] The ordered relation
      def apply_rails_ordering(relation, order_hash)
        relation.order(order_hash)
      end

      # Check if scope is a registered Orderable scope
      # @param scope_name [Symbol] The scope name to check
      # @return [Boolean] True if the scope is registered in orderable_scopes
      def is_orderable_scope?(scope_name)
        respond_to?(:orderable_scopes) && orderable_scopes.include?(scope_name)
      end

      # Paginazione custom senza dipendenze
      def paginate(relation, page: 1, per_page: 20)
        page = [page.to_i, 1].max
        per_page = [[per_page.to_i, 1].max, 100].min # Max 100 per page

        offset_value = (page - 1) * per_page

        paginated = relation.limit(per_page).offset(offset_value)

        # Aggiungi metodi helper per info paginazione
        # NOTA: total_count viene memoizzato per evitare query COUNT multiple
        paginated.define_singleton_method(:current_page) { page }
        paginated.define_singleton_method(:per_page) { per_page }
        paginated.define_singleton_method(:total_count) do
          @_total_count ||= relation.count(:all)
        end
        paginated.define_singleton_method(:total_pages) do
          @_total_pages ||= (total_count.to_f / per_page).ceil
        end

        paginated
      end

      # Valida che i predicati esistano come scope sul modello
      def validate_predicates!(predicates)
        invalid = predicates.keys.reject { |pred| respond_to?(pred) }

        if invalid.any?
          raise ArgumentError, "Invalid predicates: #{invalid.join(', ')}"
        end
      end

      # Validate that all required predicates for the scope are present and non-nil
      # @param predicates [Hash] The predicates hash from search
      # @param scope [Symbol] The scope name
      # @raise [RequiredPredicateError] If any required predicate is missing or nil
      def validate_required_predicates!(predicates, scope)
        required = required_predicates_by_scope[scope.to_sym]
        return if required.nil? || required.empty?

        # Find missing predicates (not present OR present but nil)
        missing = required.select do |req_pred|
          !predicates.key?(req_pred) || predicates[req_pred].nil?
        end

        if missing.any?
          raise RequiredPredicateError.new(scope, missing)
        end
      end

      # Helper per creare scope di ricerca testuale case-insensitive
      def define_text_search_scope(field_name)
        validate_field_name!(field_name)

        scope :"#{field_name}_i_cont", lambda { |value|
          return all if value.blank?

          lowercase_field = Arel::Nodes::NamedFunction.new('LOWER', [arel_table[field_name]])
          where(lowercase_field.matches("%#{sanitize_sql_like(value.to_s.downcase)}%"))
        }
      end

      # Helper per creare scope di uguaglianza
      def define_equality_scope(field_name)
        validate_field_name!(field_name)

        scope :"#{field_name}_eq", lambda { |value|
          where(field_name => value) if value.present?
        }
      end

      # Helper per creare tutti i predicati di confronto
      def define_comparison_scopes(field_name)
        validate_field_name!(field_name)

        scope :"#{field_name}_eq", lambda { |value|
          return all if value.blank? && !value.is_a?(FalseClass)

          where(arel_table[field_name].eq(value))
        }

        scope :"#{field_name}_not_eq", lambda { |value|
          return all if value.blank? && !value.is_a?(FalseClass)

          where(arel_table[field_name].not_eq(value))
        }

        scope :"#{field_name}_lt", lambda { |value|
          return all if value.blank?

          where(arel_table[field_name].lt(value))
        }

        scope :"#{field_name}_lteq", lambda { |value|
          return all if value.blank?

          where(arel_table[field_name].lteq(value))
        }

        scope :"#{field_name}_gt", lambda { |value|
          return all if value.blank?

          where(arel_table[field_name].gt(value))
        }

        scope :"#{field_name}_gteq", lambda { |value|
          return all if value.blank?

          where(arel_table[field_name].gteq(value))
        }
      end

      # Helper per creare predicati di pattern matching
      def define_pattern_scopes(field_name)
        validate_field_name!(field_name)

        scope :"#{field_name}_matches", lambda { |value|
          return all if value.blank?

          where(arel_table[field_name].matches(sanitize_sql_like(value)))
        }

        scope :"#{field_name}_start", lambda { |value|
          return all if value.blank?

          where(arel_table[field_name].matches("#{sanitize_sql_like(value)}%"))
        }

        scope :"#{field_name}_end", lambda { |value|
          return all if value.blank?

          where(arel_table[field_name].matches("%#{sanitize_sql_like(value)}"))
        }

        scope :"#{field_name}_cont", lambda { |value|
          return all if value.blank?

          where(arel_table[field_name].matches("%#{sanitize_sql_like(value)}%"))
        }

        scope :"#{field_name}_not_cont", lambda { |value|
          return all if value.blank?

          where(arel_table[field_name].does_not_match("%#{sanitize_sql_like(value)}%"))
        }
      end

      # Helper per creare predicati case-insensitive
      def define_case_insensitive_pattern_scopes(field_name)
        validate_field_name!(field_name)

        scope :"#{field_name}_i_cont", lambda { |value|
          return all if value.blank?

          lowercase_field = Arel::Nodes::NamedFunction.new('LOWER', [arel_table[field_name]])
          sanitized = sanitize_sql_like(value.to_s.downcase)
          where(lowercase_field.matches("%#{sanitized}%"))
        }

        scope :"#{field_name}_not_i_cont", lambda { |value|
          return all if value.blank?

          lowercase_field = Arel::Nodes::NamedFunction.new('LOWER', [arel_table[field_name]])
          sanitized = sanitize_sql_like(value.to_s.downcase)
          where(lowercase_field.does_not_match("%#{sanitized}%"))
        }
      end

      # Helper per creare predicati di array/inclusione
      def define_array_scopes(field_name)
        validate_field_name!(field_name)

        scope :"#{field_name}_in", lambda { |values|
          return all unless values.present? && values.respond_to?(:each)

          where(arel_table[field_name].in(Array(values)))
        }

        scope :"#{field_name}_not_in", lambda { |values|
          return all unless values.present? && values.respond_to?(:each)

          where(arel_table[field_name].not_in(Array(values)))
        }
      end

      # Helper per creare predicati di presenza/null
      def define_presence_scopes(field_name)
        validate_field_name!(field_name)

        scope :"#{field_name}_present", lambda { |value|
          if truthy?(value)
            where(arel_table[field_name].not_eq(nil).and(arel_table[field_name].not_eq('')))
          elsif falsy?(value)
            where(arel_table[field_name].eq(nil).or(arel_table[field_name].eq('')))
          else
            all
          end
        }

        scope :"#{field_name}_blank", lambda { |value|
          if truthy?(value)
            where(arel_table[field_name].eq(nil).or(arel_table[field_name].eq('')))
          elsif falsy?(value)
            where(arel_table[field_name].not_eq(nil).and(arel_table[field_name].not_eq('')))
          else
            all
          end
        }

        scope :"#{field_name}_null", lambda { |value|
          if truthy?(value)
            where(arel_table[field_name].eq(nil))
          elsif falsy?(value)
            where(arel_table[field_name].not_eq(nil))
          else
            all
          end
        }
      end

      # Helper per predicati numerici (senza controllo stringa vuota)
      def define_numeric_presence_scopes(field_name)
        validate_field_name!(field_name)

        scope :"#{field_name}_present", lambda { |value|
          if truthy?(value)
            where(arel_table[field_name].not_eq(nil))
          elsif falsy?(value)
            where(arel_table[field_name].eq(nil))
          else
            all
          end
        }

        scope :"#{field_name}_null", lambda { |value|
          if truthy?(value)
            where(arel_table[field_name].eq(nil))
          elsif falsy?(value)
            where(arel_table[field_name].not_eq(nil))
          else
            all
          end
        }
      end

      # Helper per predicati datetime
      def define_datetime_presence_scopes(field_name)
        validate_field_name!(field_name)

        scope :"#{field_name}_present", lambda { |value|
          if truthy?(value)
            where(arel_table[field_name].not_eq(nil))
          elsif falsy?(value)
            where(arel_table[field_name].eq(nil))
          else
            all
          end
        }

        scope :"#{field_name}_null", lambda { |value|
          if truthy?(value)
            where(arel_table[field_name].eq(nil))
          elsif falsy?(value)
            where(arel_table[field_name].not_eq(nil))
          else
            all
          end
        }
      end

      # Helper per predicati booleani
      def define_boolean_scopes(field_name)
        validate_field_name!(field_name)

        scope :"#{field_name}_true", lambda { |value|
          truthy?(value) ? where(arel_table[field_name].eq(true)) : all
        }

        scope :"#{field_name}_false", lambda { |value|
          truthy?(value) ? where(arel_table[field_name].eq(false)) : all
        }
      end

      # === MACRO PREDICATES ===

      # Genera tutti i predicati per campi stringa
      def define_string_predicates(*field_names)
        field_names.each do |field_name|
          define_comparison_scopes(field_name)
          define_pattern_scopes(field_name)
          define_case_insensitive_pattern_scopes(field_name)
          define_array_scopes(field_name)
          define_presence_scopes(field_name)
        end
      end

      # Genera tutti i predicati per campi numerici
      def define_numeric_predicates(*field_names)
        field_names.each do |field_name|
          define_comparison_scopes(field_name)
          define_array_scopes(field_name)
          define_numeric_presence_scopes(field_name)
        end
      end

      # Genera tutti i predicati per campi booleani
      def define_boolean_predicates(*field_names)
        field_names.each do |field_name|
          define_comparison_scopes(field_name)
          define_boolean_scopes(field_name)
          define_presence_scopes(field_name)
        end
      end

      # Genera tutti i predicati per campi data/datetime
      def define_date_predicates(*field_names)
        field_names.each do |field_name|
          define_comparison_scopes(field_name)
          define_array_scopes(field_name)
          define_datetime_presence_scopes(field_name)
        end
      end

      # Genera tutti i predicati per campi enum
      def define_enum_predicates(*field_names)
        field_names.each do |field_name|
          define_comparison_scopes(field_name)
          define_array_scopes(field_name)
          define_presence_scopes(field_name)
          define_pattern_scopes(field_name)
        end
      end

      # Genera tutti i predicati per foreign keys
      def define_foreign_key_predicates(*field_names)
        field_names.each do |field_name|
          define_comparison_scopes(field_name)
          define_array_scopes(field_name)
          define_presence_scopes(field_name)
        end
      end

      # Genera predicati automatici basati sul tipo di colonna
      def define_auto_predicates(*field_names)
        field_names.each do |field_name|
          validate_field_name!(field_name)

          column = columns_hash[field_name.to_s]
          next unless column

          case column.type
          when :string, :text
            define_string_predicates(field_name)
          when :integer, :decimal, :float, :bigint
            define_numeric_predicates(field_name)
          when :boolean
            define_boolean_predicates(field_name)
          when :date, :datetime, :time, :timestamp
            define_date_predicates(field_name)
          else
            # Default: predicati base
            define_comparison_scopes(field_name)
            define_array_scopes(field_name)
            define_presence_scopes(field_name)
          end
        end
      end

      private

      def validate_field_name!(field_name)
        raise ArgumentError, "Invalid field name: #{field_name}" unless column_names.include?(field_name.to_s)
      end

      def truthy?(value)
        value.to_s == 'true' || value == true || value == '1'
      end

      def falsy?(value)
        value.to_s == 'false' || value == false || value == '0'
      end
    end
  end
end
```

**Caratteristiche:**
- Auto-generazione predicati basati sul tipo SQL della colonna
- Registry pattern per predicati complessi custom
- Usa Arel per sicurezza SQL
- Supporto completo per tutti i tipi di confronto
- API unificata con `search(predicates)`

### 4.6.3 Esempi di Utilizzo

#### Esempio Base: Definizione Predicati

```ruby
class Article < ApplicationRecord
  include BetterModel::Searchable

  # Auto-genera predicati basati sul tipo di colonna
  define_auto_predicates :title, :content, :status, :published_at, :view_count

  # Equivalente manuale:
  # define_string_predicates :title, :content
  # define_enum_predicates :status
  # define_date_predicates :published_at
  # define_numeric_predicates :view_count
end

# Predicati generati automaticamente per :title (string):
# - title_eq, title_not_eq
# - title_matches, title_start, title_end, title_cont, title_not_cont
# - title_i_cont, title_not_i_cont (case-insensitive)
# - title_in, title_not_in
# - title_present, title_blank, title_null
```

#### Esempio: Ricerca Avanzata

```ruby
# Ricerca con predicati multipli
results = Article.search(
  title_i_cont: 'rails',
  status_in: ['published', 'featured'],
  published_at_gteq: 1.month.ago,
  view_count_gt: 100,
  author_id_eq: current_user.id
)

# Equivalente a:
results = Article.all
  .title_i_cont('rails')
  .status_in(['published', 'featured'])
  .published_at_gteq(1.month.ago)
  .view_count_gt(100)
  .author_id_eq(current_user.id)
```

#### Esempio: Predicati Complessi Custom

```ruby
class Order < ApplicationRecord
  include BetterModel::Searchable

  define_auto_predicates :status, :total, :created_at

  # Registra predicato complesso per ricerca full-text su più campi
  register_complex_predicate :full_text_search do |relation, query|
    relation.where(
      "LOWER(CONCAT(customer_name, ' ', customer_email, ' ', notes)) LIKE ?",
      "%#{query.downcase}%"
    )
  end

  # Registra predicato per range di date con nome custom
  register_complex_predicate :recent do |relation, days|
    relation.where('created_at >= ?', days.days.ago)
  end

  # Registra predicato per logica business complessa
  register_complex_predicate :high_value do |relation, min_total|
    relation
      .where('total >= ?', min_total)
      .where(status: ['completed', 'processing'])
      .where('created_at >= ?', 6.months.ago)
  end
end

# Uso:
Order.search(
  full_text_search: 'john',
  recent: 7,
  high_value: 1000
)
```

#### Esempio: Integrazione con Controller

```ruby
class ArticlesController < ApplicationController
  def index
    @articles = Article.search(search_params).page(params[:page])
  end

  private

  def search_params
    params.fetch(:search, {}).permit(
      :title_i_cont,
      :content_i_cont,
      :status_eq,
      :published_at_gteq,
      :published_at_lteq,
      :view_count_gt,
      status_in: [],
      author_id_in: []
    )
  end
end
```

#### Esempio: Form di Ricerca

```erb
<%= form_with url: articles_path, method: :get, local: true do |f| %>
  <div class="field">
    <%= f.label "search[title_i_cont]", "Title contains" %>
    <%= f.text_field "search[title_i_cont]", value: params.dig(:search, :title_i_cont) %>
  </div>

  <div class="field">
    <%= f.label "search[status_in][]", "Status" %>
    <%= f.select "search[status_in][]",
                 Article.statuses.keys,
                 { selected: params.dig(:search, :status_in) },
                 { multiple: true } %>
  </div>

  <div class="field">
    <%= f.label "search[published_at_gteq]", "Published after" %>
    <%= f.date_field "search[published_at_gteq]", value: params.dig(:search, :published_at_gteq) %>
  </div>

  <div class="field">
    <%= f.label "search[view_count_gt]", "Min views" %>
    <%= f.number_field "search[view_count_gt]", value: params.dig(:search, :view_count_gt) %>
  </div>

  <%= f.submit "Search" %>
<% end %>
```

### 4.6.4 Predicati Disponibili per Tipo

#### String/Text
- `#{field}_eq` / `#{field}_not_eq` - Uguaglianza
- `#{field}_matches` - Pattern matching SQL
- `#{field}_start` / `#{field}_end` / `#{field}_cont` - Starts/ends/contains
- `#{field}_not_cont` - Not contains
- `#{field}_i_cont` / `#{field}_not_i_cont` - Case-insensitive contains
- `#{field}_in` / `#{field}_not_in` - Array inclusion
- `#{field}_present` / `#{field}_blank` / `#{field}_null` - Presenza

#### Numeric (Integer, Decimal, Float)
- `#{field}_eq` / `#{field}_not_eq` - Uguaglianza
- `#{field}_lt` / `#{field}_lteq` - Minore di / minore o uguale
- `#{field}_gt` / `#{field}_gteq` - Maggiore di / maggiore o uguale
- `#{field}_in` / `#{field}_not_in` - Array inclusion
- `#{field}_present` / `#{field}_null` - Presenza

#### Boolean
- `#{field}_eq` / `#{field}_not_eq` - Uguaglianza
- `#{field}_true` / `#{field}_false` - Predicati specifici
- `#{field}_present` / `#{field}_null` - Presenza

#### Date/DateTime
- `#{field}_eq` / `#{field}_not_eq` - Uguaglianza
- `#{field}_lt` / `#{field}_lteq` - Prima di
- `#{field}_gt` / `#{field}_gteq` - Dopo di
- `#{field}_in` / `#{field}_not_in` - Array inclusion
- `#{field}_present` / `#{field}_null` - Presenza

#### Enum
- `#{field}_eq` / `#{field}_not_eq` - Uguaglianza
- `#{field}_in` / `#{field}_not_in` - Array inclusion
- `#{field}_matches` / `#{field}_cont` - Pattern matching
- `#{field}_present` / `#{field}_null` - Presenza

---

## Fase 4.7: Orderable - Sistema di Ordinamento Avanzato

### 4.7.1 Panoramica

**Orderable** fornisce un sistema completo di ordinamento per modelli ActiveRecord con:
- Auto-generazione scope di ordinamento basati sul tipo
- Scope base per ordinamento generico e multiplo
- Ordinamento case-insensitive per stringhe
- Gestione NULL per campi numerici
- Shortcuts per date (newest/oldest)
- Integrazione perfetta con Searchable

### 4.7.2 Concern Orderable
**File:** `lib/better_model/orderable.rb`

**Obiettivo:** Sistema di ordinamento dichiarativo e type-aware

```ruby
# frozen_string_literal: true

module BetterModel
  module Orderable
    extend ActiveSupport::Concern

    included do
      # Validate that the including class is an ActiveRecord model
      # Orderable requires ActiveRecord-specific features (arel_table, column_names, scope)
      unless ancestors.include?(ActiveRecord::Base)
        raise ArgumentError, "BetterModel::Orderable can only be included in ActiveRecord models. " \
                             "The class #{name} does not inherit from ActiveRecord::Base."
      end

      # Registry per tracciare tutti gli scope Orderable creati
      class_attribute :orderable_scopes, default: Set.new

      # Scope base per ordinamenti generici
      scope :order_by, lambda { |field, direction = 'asc'|
        return all if field.blank?

        direction = direction.to_s.downcase
        return all unless %w[asc desc].include?(direction)

        # Validazione sicurezza per prevenire SQL injection
        field_name = field.to_s
        return all unless column_names.include?(field_name)

        if direction == 'asc'
          order(arel_table[field_name].asc)
        else
          order(arel_table[field_name].desc)
        end
      }

      # Scope per ordinamenti multipli
      scope :multiple_order, lambda { |order_hash|
        return all unless order_hash.is_a?(Hash) && order_hash.present?

        result = all
        order_hash.each do |field, direction|
          result = result.order_by(field, direction)
        end
        result
      }
    end

    class_methods do
      # Helper principale per creare scope di ordinamento per qualsiasi campo
      def define_ordering_scope(field_name)
        validate_orderable_field!(field_name)

        # Registra scope nel registry
        register_orderable_scopes(
          :"#{field_name}_direction",
          :"#{field_name}_asc",
          :"#{field_name}_desc"
        )

        # Scope principale con direzione parametrica
        scope :"#{field_name}_direction", lambda { |direction = 'asc'|
          direction = direction.to_s.downcase
          return all unless %w[asc desc].include?(direction)

          if direction == 'asc'
            order(arel_table[field_name].asc)
          else
            order(arel_table[field_name].desc)
          end
        }

        # Scope di scorciatoia ascendente
        scope :"#{field_name}_asc", lambda {
          order(arel_table[field_name].asc)
        }

        # Scope di scorciatoia discendente
        scope :"#{field_name}_desc", lambda {
          order(arel_table[field_name].desc)
        }
      end

      # Helper per ordinamenti su campi stringa
      def define_string_ordering(*field_names)
        field_names.each do |field_name|
          define_ordering_scope(field_name)

          # Registra scope aggiuntivi per string
          register_orderable_scopes(
            :"#{field_name}_i_direction",
            :"#{field_name}_i_asc",
            :"#{field_name}_i_desc"
          )

          # Aggiunge ordinamento case-insensitive per stringhe
          scope :"#{field_name}_i_direction", lambda { |direction = 'asc'|
            direction = direction.to_s.downcase
            return all unless %w[asc desc].include?(direction)

            lowercase_field = Arel::Nodes::NamedFunction.new('LOWER', [arel_table[field_name]])
            if direction == 'asc'
              order(lowercase_field.asc)
            else
              order(lowercase_field.desc)
            end
          }

          scope :"#{field_name}_i_asc", lambda {
            lowercase_field = Arel::Nodes::NamedFunction.new('LOWER', [arel_table[field_name]])
            order(lowercase_field.asc)
          }

          scope :"#{field_name}_i_desc", lambda {
            lowercase_field = Arel::Nodes::NamedFunction.new('LOWER', [arel_table[field_name]])
            order(lowercase_field.desc)
          }
        end
      end

      # Helper per ordinamenti su campi numerici
      def define_numeric_ordering(*field_names)
        field_names.each do |field_name|
          define_ordering_scope(field_name)

          # Registra scope aggiuntivi per numeric
          register_orderable_scopes(
            :"#{field_name}_nulls_last",
            :"#{field_name}_nulls_first"
          )

          # Aggiunge ordinamento con gestione NULL per numerici
          # NOTA: Supporto cross-database per NULLS LAST/FIRST
          scope :"#{field_name}_nulls_last", lambda { |direction = 'asc'|
            direction = direction.to_s.downcase
            return all unless %w[asc desc].include?(direction)

            order_with_nulls_handling(field_name, direction, :last)
          }

          scope :"#{field_name}_nulls_first", lambda { |direction = 'asc'|
            direction = direction.to_s.downcase
            return all unless %w[asc desc].include?(direction)

            order_with_nulls_handling(field_name, direction, :first)
          }
        end
      end

      # Helper privato per gestire NULLS LAST/FIRST in modo cross-database
      # PostgreSQL e SQLite 3.30+ supportano nativamente NULLS LAST/FIRST
      # MySQL/MariaDB richiedono CASE WHEN per simulare il comportamento
      def order_with_nulls_handling(field_name, direction, nulls_position)
        quoted_field = connection.quote_column_name(field_name)
        direction_sql = direction.upcase

        case connection.adapter_name
        when 'PostgreSQL', 'SQLite'
          # Supporto nativo per NULLS LAST/FIRST
          nulls_clause = nulls_position == :last ? 'NULLS LAST' : 'NULLS FIRST'
          order(Arel.sql("#{quoted_field} #{direction_sql} #{nulls_clause}"))
        when 'MySQL', 'Mysql2', 'Trilogy', 'MariaDB'
          # MySQL/MariaDB: usa CASE per simulare NULLS LAST/FIRST
          if nulls_position == :last
            # NULL values vanno alla fine
            order(Arel.sql("CASE WHEN #{quoted_field} IS NULL THEN 1 ELSE 0 END, #{quoted_field} #{direction_sql}"))
          else
            # NULL values vanno all'inizio
            order(Arel.sql("CASE WHEN #{quoted_field} IS NULL THEN 0 ELSE 1 END, #{quoted_field} #{direction_sql}"))
          end
        else
          # Fallback per database sconosciuti: ordinamento standard senza gestione NULL
          Rails.logger.warn "[BetterModel::Orderable] NULLS #{nulls_position.upcase} not supported for #{connection.adapter_name}, using standard ordering"
          order(arel_table[field_name].send(direction.to_sym))
        end
      end

      # Helper per ordinamenti su campi data/datetime
      def define_date_ordering(*field_names)
        field_names.each do |field_name|
          define_ordering_scope(field_name)

          # Registra scope aggiuntivi per date
          register_orderable_scopes(
            :"#{field_name}_newest",
            :"#{field_name}_oldest"
          )

          # Aggiunge ordinamenti di data più recente/meno recente
          scope :"#{field_name}_newest", lambda {
            order(arel_table[field_name].desc)
          }

          scope :"#{field_name}_oldest", lambda {
            order(arel_table[field_name].asc)
          }
        end
      end

      # Genera ordinamenti per tutti i tipi di campo
      def define_orderable_fields(*field_names)
        field_names.each do |field_name|
          define_auto_ordering(field_name)
        end
      end

      # Genera ordinamenti con auto-rilevamento tipo campo
      def define_auto_ordering(field_name)
        validate_orderable_field!(field_name)

        column = columns_hash[field_name.to_s]
        return define_ordering_scope(field_name) unless column

        case column.type
        when :string, :text
          define_string_ordering(field_name)
        when :integer, :decimal, :float, :bigint
          define_numeric_ordering(field_name)
        when :date, :datetime, :time, :timestamp
          define_date_ordering(field_name)
        else
          # Default: ordinamento base per campi sconosciuti
          define_ordering_scope(field_name)
        end
      end

      # Macro per configurazione completa campi stringa
      def define_string_orderable_fields(*field_names)
        field_names.each do |field_name|
          define_string_ordering(field_name)
        end
      end

      # Macro per configurazione completa campi numerici
      def define_numeric_orderable_fields(*field_names)
        field_names.each do |field_name|
          define_numeric_ordering(field_name)
        end
      end

      # Macro per configurazione completa campi data
      def define_date_orderable_fields(*field_names)
        field_names.each do |field_name|
          define_date_ordering(field_name)
        end
      end

      private

      def validate_orderable_field!(field_name)
        raise ArgumentError, "Invalid orderable field: #{field_name}" unless column_names.include?(field_name.to_s)
      end

      # Register Orderable scopes in the registry
      def register_orderable_scopes(*scope_names)
        self.orderable_scopes = orderable_scopes + scope_names
      end
    end

    # Metodi di istanza per ordinamenti
    def orderable_attributes
      # Restituisce gli attributi che possono essere ordinati per questo modello
      self.class.column_names.reject do |attr|
        %w[password_digest encrypted_email encrypted_first_name encrypted_last_name].include?(attr)
      end
    end

    # Helper per ottenere la direzione di ordinamento opposta
    def toggle_direction(current_direction)
      current_direction.to_s.downcase == 'asc' ? 'desc' : 'asc'
    end
  end
end
```

### 4.7.3 Esempi di Utilizzo

#### Esempio Base: Definizione Ordering

```ruby
class Article < ApplicationRecord
  include BetterModel::Orderable

  # Auto-genera scope di ordinamento basati sul tipo
  define_orderable_fields :title, :published_at, :view_count
end

# Scope generati per :title (string):
# - title_direction(direction)
# - title_asc, title_desc
# - title_i_direction(direction) - case-insensitive
# - title_i_asc, title_i_desc

# Scope generati per :view_count (numeric):
# - view_count_asc, view_count_desc
# - view_count_nulls_last(direction)
# - view_count_nulls_first(direction)

# Scope generati per :published_at (date):
# - published_at_asc, published_at_desc
# - published_at_newest, published_at_oldest
```

#### Esempio: Ordinamento Base

```ruby
# Ordinamento semplice
Article.title_asc
Article.view_count_desc
Article.published_at_newest

# Ordinamento con direzione parametrica
Article.title_direction('desc')
Article.view_count_direction('asc')

# Ordinamento case-insensitive per stringhe
Article.title_i_asc
Article.title_i_direction('desc')

# Ordinamento generico (utile per parametri dinamici)
Article.order_by(:title, :asc)
Article.order_by(:view_count, :desc)
```

#### Esempio: Ordinamento Multiplo

```ruby
# Ordinamento multiplo
Article
  .published_at_newest
  .title_asc

# Ordinamento multiplo con hash
Article.multiple_order(
  published_at: :desc,
  title: :asc,
  view_count: :desc
)
```

#### Esempio: Gestione NULL per Numerici

```ruby
# Metti valori NULL alla fine
Article.view_count_nulls_last('desc')

# Metti valori NULL all'inizio
Article.view_count_nulls_first('asc')
```

### 4.7.4 Integrazione con Searchable

```ruby
class Article < ApplicationRecord
  include BetterModel::Searchable
  include BetterModel::Orderable

  define_auto_predicates :title, :status, :view_count, :published_at
  define_orderable_fields :title, :view_count, :published_at
end

# Ricerca con ordinamento tramite Orderable scope
Article.search(
  { title_i_cont: 'rails', status_eq: 'published' },
  order: :published_at_newest,
  page: 1,
  per_page: 20
)

# Ricerca con ordinamento SQL diretto (Rails standard)
Article.search(
  { title_i_cont: 'rails' },
  order: { view_count: :desc },
  page: 1
)

# Ricerca con ordinamento misto (array)
Article.search(
  { status_eq: 'published' },
  order: [:published_at_newest, { view_count: :desc }],
  page: 2
)
```

---

## Fase 5: Concerns Riutilizzabili

**Directory:** `lib/better_model/concerns/`

Questa directory conterrà concerns comuni e riutilizzabili. Esempi:

### Timestampable (esempio)
**File:** `lib/better_model/concerns/timestampable.rb`

```ruby
# frozen_string_literal: true

require "active_support/concern"

module BetterModel
  module Concerns
    module Timestampable
      extend ActiveSupport::Concern

      included do
        before_save :update_timestamps
      end

      private

      def update_timestamps
        now = Time.current
        self.updated_at = now
        self.created_at = now if new_record?
      end
    end
  end
end
```

---

## Fase 6: Test Suite

### 6.1 Attributes Test
**File:** `test/better_model/attributes_test.rb`

```ruby
require "test_helper"

class AttributesTest < ActiveSupport::TestCase
  setup do
    @model_class = Class.new do
      include ActiveModel::Model
      include BetterModel::Attributes
    end
  end

  test "typed_attribute defines attribute with custom type" do
    @model_class.typed_attribute :email, :email

    instance = @model_class.new(email: " TEST@EXAMPLE.COM ")
    assert_equal "test@example.com", instance.email
  end

  test "email_attribute adds validation" do
    @model_class.email_attribute :contact_email

    instance = @model_class.new(contact_email: "invalid")
    refute instance.valid?
  end

  test "attributes_of_type defines multiple attributes" do
    @model_class.attributes_of_type :string, :name, :title

    instance = @model_class.new(name: "John", title: "Mr")
    assert_equal "John", instance.name
    assert_equal "Mr", instance.title
  end
end
```

### 6.2 Validations Test
**File:** `test/better_model/validations_test.rb`

```ruby
require "test_helper"

class ValidationsTest < ActiveSupport::TestCase
  setup do
    @model_class = Class.new do
      include ActiveModel::Model
      include BetterModel::Validations

      attr_accessor :email, :name, :website
    end
  end

  test "required validates presence" do
    @model_class.required :name

    instance = @model_class.new
    refute instance.valid?
    assert_includes instance.errors[:name], "can't be blank"
  end

  test "validates_email checks format" do
    @model_class.validates_email :email

    instance = @model_class.new(email: "invalid")
    refute instance.valid?

    instance.email = "valid@example.com"
    assert instance.valid?
  end

  test "validates_on creates context-specific validations" do
    @model_class.validates_on :custom do
      required :name
    end

    instance = @model_class.new
    assert instance.valid?
    refute instance.valid?(:custom)
  end
end
```

### 6.3 State Machine Test
**File:** `test/better_model/state_machine_test.rb`

```ruby
require "test_helper"

class StateMachineTest < ActiveSupport::TestCase
  setup do
    @model_class = Class.new do
      include ActiveModel::Model
      include BetterModel::StateMachine

      attr_accessor :status

      state_machine :status do
        initial :draft
        states :draft, :published, :archived

        transition :publish, from: :draft, to: :published
        transition :archive, from: :published, to: :archived
      end
    end
  end

  test "initial state is set" do
    instance = @model_class.new
    assert_equal :draft, instance.status
  end

  test "state query methods are defined" do
    instance = @model_class.new
    assert instance.in_draft?
    refute instance.in_published?
  end

  test "transition methods are defined" do
    instance = @model_class.new
    assert_respond_to instance, :to_published!
    assert_respond_to instance, :can_to_published?
  end

  test "can_to_state? checks validity" do
    instance = @model_class.new
    assert instance.can_to_published?

    instance.status = :archived
    refute instance.can_to_published?
  end

  test "to_state! executes transition" do
    instance = @model_class.new
    instance.to_published!
    assert instance.in_published?
  end

  test "was_state? checks previous state" do
    instance = @model_class.new
    assert instance.in_draft?

    instance.to_published!
    assert instance.in_published?
    assert instance.was_draft?
    refute instance.was_published?
  end
end
```

### 6.4 Statusable Test
**File:** `test/better_model/statusable_test.rb`

```ruby
require "test_helper"

class StatusableTest < ActiveSupport::TestCase
  setup do
    @model_class = Class.new do
      include ActiveModel::Model
      include BetterModel::Statusable

      attr_accessor :status, :expires_at, :scheduled_at

      is :pending, -> { status == 'initialized' }
      is :expired, -> { expires_at.present? && expires_at <= Time.current }
      is :scheduled, -> { scheduled_at.present? }
      is :ready, -> { scheduled? && scheduled_at <= Time.current }
    end
  end

  test "is? returns correct status" do
    instance = @model_class.new(status: 'initialized')
    assert instance.is?(:pending)
    refute instance.is?(:expired)
  end

  test "is_status? methods are generated" do
    instance = @model_class.new(status: 'initialized')
    assert_respond_to instance, :is_pending?
    assert_respond_to instance, :is_expired?
    assert instance.is_pending?
  end

  test "statuses returns all status values" do
    instance = @model_class.new(
      status: 'initialized',
      scheduled_at: 1.hour.from_now
    )

    statuses = instance.status_checks
    assert statuses[:pending]
    assert statuses[:scheduled]
    refute statuses[:expired]
    refute statuses[:ready]
  end

  test "defined_statuses returns all defined status names" do
    assert_equal [:pending, :expired, :scheduled, :ready], @model_class.defined_statuses
  end

  test "has_all_statuses? checks multiple statuses" do
    instance = @model_class.new(
      status: 'initialized',
      scheduled_at: 1.hour.from_now
    )

    assert instance.has_all_statuses?([:pending, :scheduled])
    refute instance.has_all_statuses?([:pending, :expired])
  end

  test "active_statuses filters active statuses" do
    instance = @model_class.new(status: 'initialized')

    active = instance.active_statuses([:pending, :expired, :scheduled])
    assert_equal [:pending], active
  end

  test "as_json includes statuses when requested" do
    instance = @model_class.new(status: 'initialized')

    json = instance.as_json(include_statuses: true)
    assert json['statuses']
    assert_equal 'true', json['statuses']['pending'].to_s
  end
end
```

### 6.5 Searchable Test
**File:** `test/better_model/searchable_test.rb`

```ruby
require "test_helper"

class SearchableTest < ActiveSupport::TestCase
  setup do
    # Create a test model with searchable
    @model_class = Class.new(ActiveRecord::Base) do
      self.table_name = 'articles'
      include BetterModel::Searchable

      define_auto_predicates :title, :status, :view_count, :published_at
    end
  end

  test "define_auto_predicates generates scopes based on column type" do
    # String predicates
    assert_respond_to @model_class, :title_eq
    assert_respond_to @model_class, :title_i_cont
    assert_respond_to @model_class, :title_in

    # Numeric predicates
    assert_respond_to @model_class, :view_count_gt
    assert_respond_to @model_class, :view_count_lteq

    # Date predicates
    assert_respond_to @model_class, :published_at_gteq
  end

  test "search method applies multiple predicates" do
    article1 = @model_class.create!(title: 'Rails Guide', status: 'published', view_count: 100)
    article2 = @model_class.create!(title: 'Ruby Tips', status: 'draft', view_count: 50)

    results = @model_class.search(
      title_i_cont: 'rails',
      status_eq: 'published',
      view_count_gt: 50
    )

    assert_includes results, article1
    refute_includes results, article2
  end

  test "register_complex_predicate creates custom scope" do
    @model_class.register_complex_predicate :high_performing do |relation, min_views|
      relation.where('view_count >= ?', min_views).where(status: 'published')
    end

    article1 = @model_class.create!(title: 'Popular', status: 'published', view_count: 1000)
    article2 = @model_class.create!(title: 'Unpopular', status: 'published', view_count: 10)

    results = @model_class.high_performing(100)

    assert_includes results, article1
    refute_includes results, article2
  end

  test "string predicates work correctly" do
    article = @model_class.create!(title: 'Test Article')

    assert_equal [article], @model_class.title_eq('Test Article').to_a
    assert_equal [article], @model_class.title_i_cont('test').to_a
    assert_equal [article], @model_class.title_start('Test').to_a
    assert_equal [article], @model_class.title_end('Article').to_a
  end

  test "numeric predicates work correctly" do
    article1 = @model_class.create!(title: 'A', view_count: 50)
    article2 = @model_class.create!(title: 'B', view_count: 150)

    assert_equal [article2], @model_class.view_count_gt(100).to_a
    assert_equal [article1], @model_class.view_count_lt(100).to_a
    assert_equal [article1, article2], @model_class.view_count_gteq(50).to_a
  end

  test "array predicates work correctly" do
    article1 = @model_class.create!(title: 'A', status: 'published')
    article2 = @model_class.create!(title: 'B', status: 'draft')
    article3 = @model_class.create!(title: 'C', status: 'archived')

    results = @model_class.status_in(['published', 'archived']).to_a

    assert_includes results, article1
    refute_includes results, article2
    assert_includes results, article3
  end

  test "presence predicates work correctly" do
    article1 = @model_class.create!(title: 'With Content', content: 'Lorem ipsum')
    article2 = @model_class.create!(title: 'Without Content', content: nil)

    present_results = @model_class.content_present(true).to_a
    null_results = @model_class.content_null(true).to_a

    assert_includes present_results, article1
    assert_includes null_results, article2
  end

  test "advanced search with pagination" do
    10.times { |i| @model_class.create!(title: "Article #{i}", view_count: i * 10) }

    results = @model_class.search({}, page: 2, per_page: 3)

    assert_equal 2, results.current_page
    assert_equal 3, results.per_page
    assert_equal 4, results.total_pages
    assert_equal 10, results.total_count
  end

  test "advanced search with includes" do
    # Assuming Article has_many :comments
    results = @model_class.search({}, includes: [:comments])

    # Verify that includes were applied (would need actual associations in test)
    assert_instance_of ActiveRecord::Relation, results
  end

  test "advanced search with order" do
    @model_class.create!(title: 'B', view_count: 100)
    @model_class.create!(title: 'A', view_count: 200)

    results = @model_class.search({}, order: { view_count: :desc }, limit: nil)

    assert_equal 200, results.first.view_count
  end

  test "advanced search with limit" do
    5.times { |i| @model_class.create!(title: "Article #{i}") }

    # limit: 1 returns single record
    result = @model_class.search({}, limit: 1)
    assert_instance_of @model_class, result

    # limit: n returns relation with limit
    results = @model_class.search({}, limit: 3)
    assert_equal 3, results.count

    # limit: nil returns all without pagination
    all_results = @model_class.search({}, limit: nil)
    assert_equal 5, all_results.count
  end

  test "require_predicates_for_scope raises error when predicates missing" do
    @model_class.require_predicates_for_scope :admin, :status_eq, :category_eq

    error = assert_raises(BetterModel::Searchable::RequiredPredicateError) do
      @model_class.search({}, scope: :admin)
    end

    assert_equal :admin, error.scope
    assert_includes error.missing_predicates, :status_eq
    assert_includes error.missing_predicates, :category_eq
  end

  test "require_predicates_for_scope raises error when predicates are nil" do
    @model_class.require_predicates_for_scope :admin, :status_eq

    error = assert_raises(BetterModel::Searchable::RequiredPredicateError) do
      @model_class.search({ status_eq: nil }, scope: :admin)
    end

    assert_equal :admin, error.scope
    assert_includes error.missing_predicates, :status_eq
  end

  test "require_predicates_for_scope succeeds when all predicates provided" do
    @model_class.require_predicates_for_scope :admin, :status_eq, :category_eq

    article1 = @model_class.create!(title: 'Article 1', status: 'published', category: 'tech')
    article2 = @model_class.create!(title: 'Article 2', status: 'draft', category: 'tech')

    result = @model_class.search(
      { status_eq: 'published', category_eq: 'tech' },
      scope: :admin,
      limit: nil
    )

    assert_instance_of ActiveRecord::Relation, result
    assert_includes result, article1
    refute_includes result, article2
  end

  test "default scope does not enforce required predicates" do
    @model_class.require_predicates_for_scope :admin, :status_eq

    # Should not raise error even though status_eq is missing
    result = @model_class.search({}, scope: :default)
    assert_instance_of ActiveRecord::Relation, result
  end

  test "scope :default is implicit when scope not specified" do
    @model_class.require_predicates_for_scope :admin, :status_eq

    # Should not raise error - scope defaults to :default
    result = @model_class.search({})
    assert_instance_of ActiveRecord::Relation, result
  end

  test "require_predicates_for_scope allows partial predicates when only some required" do
    @model_class.require_predicates_for_scope :admin, :status_eq

    article = @model_class.create!(title: 'Article', status: 'published', category: 'tech')

    # status_eq is required and provided, other_field_eq is optional
    result = @model_class.search(
      { status_eq: 'published', title_eq: 'Article' },
      scope: :admin,
      limit: nil
    )

    assert_instance_of ActiveRecord::Relation, result
    assert_includes result, article
  end

  test "require_predicates_for_scope supports multiple scopes" do
    @model_class.require_predicates_for_scope :admin, :status_eq
    @model_class.require_predicates_for_scope :public, :published_eq

    # Admin scope requires status_eq
    error = assert_raises(BetterModel::Searchable::RequiredPredicateError) do
      @model_class.search({}, scope: :admin)
    end
    assert_equal :admin, error.scope

    # Public scope requires published_eq
    error = assert_raises(BetterModel::Searchable::RequiredPredicateError) do
      @model_class.search({}, scope: :public)
    end
    assert_equal :public, error.scope
  end

  test "require_predicates_for_scope error message includes all missing predicates" do
    @model_class.require_predicates_for_scope :admin, :status_eq, :category_eq, :author_id_eq

    error = assert_raises(BetterModel::Searchable::RequiredPredicateError) do
      @model_class.search({ status_eq: 'published' }, scope: :admin)
    end

    assert_match(/category_eq/, error.message)
    assert_match(/author_id_eq/, error.message)
    refute_match(/status_eq/, error.message) # status_eq was provided
  end

  test "order parameter accepts Orderable scope symbol" do
    @model_class.create!(title: 'Old', published_at: 1.month.ago)
    @model_class.create!(title: 'New', published_at: 1.day.ago)

    results = @model_class.search({}, order: :published_at_newest, limit: nil)
    assert_equal 'New', results.first.title
  end

  test "order parameter accepts Rails hash" do
    @model_class.create!(title: 'B', view_count: 100)
    @model_class.create!(title: 'A', view_count: 200)

    results = @model_class.search({}, order: { view_count: :desc }, limit: nil)
    assert_equal 200, results.first.view_count
  end

  test "order parameter accepts mixed array" do
    results = @model_class.search(
      {},
      order: [:published_at_newest, { view_count: :desc }],
      limit: nil
    )
    assert_instance_of ActiveRecord::Relation, results
  end

  test "order with unknown Orderable scope logs warning and continues" do
    assert_nothing_raised do
      results = @model_class.search({}, order: :nonexistent_scope, limit: nil)
      assert_instance_of ActiveRecord::Relation, results
    end
  end

  test "order parameter with string converts to symbol" do
    results = @model_class.search({}, order: 'published_at_newest', limit: nil)
    assert_instance_of ActiveRecord::Relation, results
  end

  test "order parameter processes array items in sequence" do
    # Create test data to verify multiple orderings are applied
    @model_class.create!(published_at: 2.days.ago, view_count: 100, title: 'B')
    @model_class.create!(published_at: 1.day.ago, view_count: 200, title: 'A')

    results = @model_class.search(
      {},
      order: [{ published_at: :desc }, { title: :asc }],
      limit: nil
    )

    assert_equal 'A', results.first.title
  end
end
```

### 6.6 Orderable Test
**File:** `test/better_model/orderable_test.rb`

```ruby
require "test_helper"

class OrderableTest < ActiveSupport::TestCase
  setup do
    @model_class = Class.new(ActiveRecord::Base) do
      self.table_name = 'articles'
      include BetterModel::Orderable

      define_orderable_fields :title, :view_count, :published_at
    end
  end

  test "define_orderable_fields generates ordering scopes" do
    # String field scopes
    assert_respond_to @model_class, :title_asc
    assert_respond_to @model_class, :title_desc
    assert_respond_to @model_class, :title_i_asc
    assert_respond_to @model_class, :title_direction

    # Numeric field scopes
    assert_respond_to @model_class, :view_count_asc
    assert_respond_to @model_class, :view_count_desc
    assert_respond_to @model_class, :view_count_nulls_last

    # Date field scopes
    assert_respond_to @model_class, :published_at_newest
    assert_respond_to @model_class, :published_at_oldest
  end

  test "basic ordering works" do
    article1 = @model_class.create!(title: 'B', view_count: 100)
    article2 = @model_class.create!(title: 'A', view_count: 200)

    asc_results = @model_class.title_asc.to_a
    assert_equal article2, asc_results.first

    desc_results = @model_class.view_count_desc.to_a
    assert_equal article2, desc_results.first
  end

  test "case insensitive ordering for strings" do
    article1 = @model_class.create!(title: 'banana')
    article2 = @model_class.create!(title: 'Apple')
    article3 = @model_class.create!(title: 'cherry')

    results = @model_class.title_i_asc.to_a

    assert_equal article2, results.first
    assert_equal article1, results.second
    assert_equal article3, results.third
  end

  test "nulls handling for numeric fields" do
    article1 = @model_class.create!(title: 'A', view_count: 100)
    article2 = @model_class.create!(title: 'B', view_count: nil)
    article3 = @model_class.create!(title: 'C', view_count: 200)

    results = @model_class.view_count_nulls_last('asc').to_a

    assert_equal article1, results.first
    assert_equal article3, results.second
    assert_equal article2, results.third
  end

  test "order_by generic scope" do
    article1 = @model_class.create!(title: 'B')
    article2 = @model_class.create!(title: 'A')

    results = @model_class.order_by(:title, :asc).to_a

    assert_equal article2, results.first
  end

  test "multiple_order scope" do
    article1 = @model_class.create!(title: 'A', view_count: 200)
    article2 = @model_class.create!(title: 'B', view_count: 100)
    article3 = @model_class.create!(title: 'A', view_count: 100)

    results = @model_class.multiple_order(title: :asc, view_count: :desc).to_a

    assert_equal article1, results.first
    assert_equal article3, results.second
    assert_equal article2, results.third
  end

  test "date ordering shortcuts" do
    article1 = @model_class.create!(title: 'Old', published_at: 1.year.ago)
    article2 = @model_class.create!(title: 'New', published_at: 1.day.ago)

    newest = @model_class.published_at_newest.to_a
    assert_equal article2, newest.first

    oldest = @model_class.published_at_oldest.to_a
    assert_equal article1, oldest.first
  end
end
```

### 6.7 Integration Test
**File:** `test/better_model/integration_test.rb`

```ruby
require "test_helper"

class IntegrationTest < ActiveSupport::TestCase
  setup do
    @model_class = Class.new do
      include ActiveModel::Model
      include BetterModel::Attributes
      include BetterModel::Validations
      include BetterModel::StateMachine

      typed_attribute :title, :string
      email_attribute :author_email

      required :title, :author_email

      attr_accessor :status

      state_machine :status do
        initial :draft
        states :draft, :published

        transition :publish, from: :draft, to: :published,
                   if: :valid?
      end
    end
  end

  test "all features work together" do
    instance = @model_class.new(
      title: "Test",
      author_email: "test@example.com"
    )

    assert instance.in_draft?
    assert instance.valid?
    assert instance.can_to_published?

    instance.to_published!
    assert instance.in_published?
  end
end
```

---

## Fase 7: Documentazione

### 7.1 Aggiornare CLAUDE.md

Aggiungere sezione sulla nuova architettura:

```markdown
## DSL Features

BetterModel provides three main DSL modules:

### Attributes (`BetterModel::Attributes`)
- `typed_attribute` - Define typed attributes with custom types
- `email_attribute` - Email attribute with validation
- `json_attribute` - JSON attribute with schema support
- Custom types: `:email`, `:url`, `:json`

### Validations (`BetterModel::Validations`)
- `required` - Expressive presence validation
- `validates_email` - Email format validation
- `validates_url` - URL format validation
- `validates_on` - Context-specific validation groups

### StateMachine (`BetterModel::StateMachine`)
- `state_machine` - Define state machines with transitions
- Automatic generation of query methods (`draft?`)
- Automatic generation of transition methods (`publish!`)
- Support for conditions and callbacks

### Statusable (`BetterModel::Statusable`)
- `is` - Define declarative status queries based on conditions
- Automatic generation of `is_#{status}?` methods
- `statuses` - Get all defined statuses with their values
- Dynamic status calculation (not persisted)
- Ideal for derived states and complex queries

### Searchable (`BetterModel::Searchable`)
- `define_auto_predicates` - Auto-generate search predicates based on column type
- `search(predicates, page:, per_page:, includes:, joins:, order:, limit:, scope:)` - Advanced search API
- `register_complex_predicate` - Define custom search logic
- `require_predicates_for_scope` - Define required predicates for multitenancy security
- Automatic scope generation for all comparison types
- Built-in pagination without dependencies
- SQL-safe queries via Arel

### Orderable (`BetterModel::Orderable`)
- `define_orderable_fields` - Auto-generate ordering scopes based on column type
- `order_by(field, direction)` - Generic ordering scope
- `multiple_order(hash)` - Order by multiple fields
- String fields: case-insensitive ordering (`field_i_asc`)
- Numeric fields: NULL handling (`field_nulls_last`)
- Date fields: shortcuts (`field_newest`, `field_oldest`)
```

### 7.2 Aggiornare README.md

```markdown
## Features

BetterModel enhances Rails models with:

- **Typed Attributes**: Custom type system extending ActiveModel::Attributes
- **Advanced Validations**: Expressive DSL for common validation patterns
- **State Machines**: Declarative state management with transitions and callbacks
- **Statusable**: Declarative status queries based on dynamic conditions
- **Searchable**: Advanced search and filtering system with pagination (Ransack alternative)
- **Orderable**: Type-aware ordering system with NULL handling
- **Reusable Concerns**: Common model functionality

## Usage

### Typed Attributes

```ruby
class User < ApplicationRecord
  include BetterModel::Attributes

  typed_attribute :name, :string
  email_attribute :email
  json_attribute :preferences, default: {}
end

user = User.new(email: " TEST@EXAMPLE.COM ")
user.email # => "test@example.com"
```

### Advanced Validations

```ruby
class Article < ApplicationRecord
  include BetterModel::Validations

  required :title, :author
  validates_email :contact_email
  validates_url :website, allow_blank: true

  validates_on :publication do
    required :summary
    validates :title, length: { minimum: 10 }
  end
end
```

### State Machine

```ruby
class Order < ApplicationRecord
  include BetterModel::StateMachine

  state_machine :status do
    initial :pending

    states :pending, :confirmed, :shipped, :delivered

    transition :confirm, from: :pending, to: :confirmed,
               if: :payment_received?,
               after: :send_confirmation_email

    transition :ship, from: :confirmed, to: :shipped
    transition :deliver, from: :shipped, to: :delivered
  end
end

order = Order.new
order.pending? # => true
order.can_confirm? # => checks conditions
order.confirm! # => transitions and runs callbacks
```

### Statusable (Declarative Status Queries)

```ruby
class Consult < ApplicationRecord
  include BetterModel::Statusable

  # Define status queries based on conditions
  is :pending, -> { status == 'initialized' }
  is :expired, -> { expires_at.present? && expires_at <= Time.current }
  is :scheduled, -> { scheduled_at.present? }
  is :ready_to_start, -> { scheduled? && scheduled_at <= Time.current }
end

consult = Consult.new(
  status: 'initialized',
  scheduled_at: 5.minutes.from_now
)

consult.is_pending?        # => true
consult.is_expired?        # => false
consult.is_scheduled?      # => true
consult.is_ready_to_start? # => false (not yet time)

# Get all statuses
consult.status_checks
# => { pending: true, expired: false, scheduled: true, ready_to_start: false }
```

### Searchable (Advanced Search & Filtering)

```ruby
class Article < ApplicationRecord
  include BetterModel::Searchable
  include BetterModel::Orderable

  # Auto-generate search predicates based on column types
  define_auto_predicates :title, :content, :status, :published_at, :view_count
  define_orderable_fields :published_at, :view_count, :title
end

# Simple search with predicates
articles = Article.search(
  title_i_cont: 'rails',
  status_in: ['published', 'featured']
)

# Advanced search with pagination and ordering
articles = Article.search(
  { title_i_cont: 'rails', status_eq: 'published' },
  page: 1,
  per_page: 20,
  order: :published_at_newest
)

# Pagination info
articles.current_page    # => 1
articles.per_page        # => 20
articles.total_pages     # => 5
articles.total_count     # => 97

# Advanced search with includes and joins
articles = Article.search(
  { author_name_cont: 'John' },
  includes: [:author, :comments],
  joins: :author,
  order: { published_at: :desc }
)

# Define custom complex predicates
Article.register_complex_predicate :trending do |relation, days|
  relation
    .where('published_at >= ?', days.days.ago)
    .where('view_count > ?', 1000)
end

Article.trending(7)  # Find trending articles from last 7 days
```

### Orderable (Type-aware Ordering)

```ruby
class Article < ApplicationRecord
  include BetterModel::Orderable

  # Auto-generate ordering scopes
  define_orderable_fields :title, :view_count, :published_at
end

# Basic ordering
Article.title_asc
Article.view_count_desc
Article.published_at_newest

# Case-insensitive ordering for strings
Article.title_i_asc

# NULL handling for numeric fields
Article.view_count_nulls_last('desc')

# Multiple ordering
Article.multiple_order(
  published_at: :desc,
  view_count: :desc,
  title: :asc
)

# Generic ordering (useful for dynamic params)
Article.order_by(params[:sort_field], params[:sort_direction])
```

## Configuration

```ruby
# config/initializers/better_model.rb
BetterModel.configure do |config|
  config.default_state_column = :status
  config.state_machine_raise_on_invalid_transition = false
end
```
```

---

## Esempio di Utilizzo Completo

```ruby
class Article < ApplicationRecord
  include BetterModel::Attributes
  include BetterModel::Validations
  include BetterModel::StateMachine
  include BetterModel::Statusable
  include BetterModel::Searchable
  include BetterModel::Orderable

  # Attributi tipizzati
  typed_attribute :title, :string, default: ""
  typed_attribute :view_count, :integer, default: 0
  email_attribute :author_email
  json_attribute :metadata, default: {}

  attributes_of_type :string, :subtitle, :summary, :content

  # Validazioni avanzate
  required :title, :author_email, :content
  validates_email :author_email
  validates_url :external_link, allow_blank: true

  validates_on :publication do
    required :subtitle, :summary
    validates :title, length: { minimum: 10, maximum: 200 }
    validates :content, length: { minimum: 100 }
  end

  # State machine per workflow principale
  state_machine :status do
    initial :draft

    states :draft, :in_review, :published, :archived

    event :submit_for_review do
      transition from: :draft, to: :in_review,
                 if: :valid_for_review?,
                 after: :notify_reviewers
    end

    transition :publish,
               from: [:draft, :in_review],
               to: :published,
               if: :valid_for_publication?,
               before: :validate_publication,
               after: :send_publication_notification

    transition :archive, from: :published, to: :archived
    transition :revert_to_draft, from: [:in_review, :archived], to: :draft
  end

  # Statusable per stati derivati
  is :publishable, -> { valid?(:publication) && in_draft? }
  is :editable, -> { in_draft? || status == 'in_review' }  # NOTA: usa confronto diretto per stati con underscore
  is :visible_to_public, -> { in_published? }
  is :needs_review, -> { in_draft? && valid? }
  is :stale, -> { updated_at < 1.month.ago }

  # Searchable per ricerca avanzata
  define_auto_predicates :title, :subtitle, :content, :status, :published_at, :view_count, :author_email

  register_complex_predicate :popular do |relation, days|
    relation
      .where('published_at >= ?', days.days.ago)
      .where('view_count > ?', 100)
      .where(status: 'published')
  end

  # Orderable per ordinamenti
  define_orderable_fields :published_at, :view_count, :title

  private

  def valid_for_review?
    title.present? && content.present? && author_email.present?
  end

  def valid_for_publication?
    valid?(:publication)
  end

  def validate_publication
    raise "Cannot publish without summary" unless summary.present?
  end

  def notify_reviewers
    ReviewerMailer.new_submission(self).deliver_later
  end

  def send_publication_notification
    AuthorMailer.published(self).deliver_later
  end
end

# Utilizzo:
article = Article.new(
  title: "Understanding Rails State Machines",
  author_email: "john@example.com",
  content: "..." * 100
)

article.in_draft?                 # => true
article.metadata                  # => {}
article.metadata = { tags: ["rails", "ruby"] }

article.valid?                    # => true
article.can_to_in_review?         # => true (stato destinazione)
article.to_in_review!             # => transitions to :in_review, sends email

article.status == 'in_review'     # => true (confronto diretto per stati con underscore)

article.subtitle = "A comprehensive guide"
article.summary = "Learn how to implement state machines"
article.valid?(:publication)      # => true

article.to_published!             # => transitions to :published, runs callbacks
article.in_published?             # => true

# Stati derivati da Statusable
article.is_publishable?           # => false (already published)
article.is_editable?              # => false (published articles not editable)
article.is_visible_to_public?     # => true
article.is_stale?                 # => false (just published)

# Tutti gli stati
article.status_checks
# => { publishable: false, editable: false, visible_to_public: true, ... }

# Ricerca avanzata con Searchable
popular_articles = Article.popular(7)  # Ultimi 7 giorni

# Ricerca con paginazione e ordinamento
search_results = Article.search(
  {
    title_i_cont: 'rails',
    status_in: ['published', 'featured'],
    published_at_gteq: 1.month.ago,
    view_count_gt: 50
  },
  page: 1,
  per_page: 20,
  order: :published_at_newest
)

# Info paginazione
search_results.current_page  # => 1
search_results.total_pages   # => 3
search_results.total_count   # => 47

# Ordinamenti diretti con Orderable
Article.published_at_newest.view_count_desc.title_i_asc
```

---

## Priorità di Implementazione

1. **Alta priorità** (Must-have):
   - Setup base (gemspec, configuration, railtie)
   - Attributes base concern
   - Type registry con tipi email, url, json
   - Validations base concern
   - State machine base, DSL, transition
   - Statusable concern
   - Searchable concern (con paginazione, includes, joins, ordering)
   - Orderable concern

2. **Media priorità** (Should-have):
   - Test suite completa (attributes, validations, state_machine, statusable, searchable, orderable, integration)
   - Custom validators aggiuntivi
   - State class per rappresentazione stati
   - Documentazione completa (README, CLAUDE.md)
   - Searchable: predicati aggiuntivi per JSON/Array columns
   - Orderable: ordinamento su associazioni

3. **Bassa priorità** (Nice-to-have):
   - Concerns riutilizzabili aggiuntivi
   - Generators per creare state machines
   - Performance optimizations
   - Error messages customizzabili
   - Scopes per Statusable (es. `Article.where_is(:publishable)`)
   - Searchable: integrazione con Elasticsearch/full-text search
   - Searchable: smart caching per query complesse

---

## Compatibilità e Conflitti Noti

### Matrice di Compatibilità Database

| Feature | PostgreSQL | MySQL/MariaDB | SQLite | Note |
|---------|------------|---------------|--------|------|
| **NULLS LAST/FIRST** | ✅ Nativo | ⚠️ Emulato (CASE) | ✅ Nativo (3.30+) | Orderable usa fallback automatico |
| **LOWER() function** | ✅ | ✅ | ✅ | Searchable case-insensitive |
| **JSON column type** | ✅ Nativo | ✅ JSON (5.7+) | ✅ TEXT | :better_json evita conflitti |
| **Arel nodes** | ✅ | ✅ | ✅ | Compatibilità completa |
| **Transactions** | ✅ | ✅ | ✅ | StateMachine supportato |
| **CONCAT** | ✅ CONCAT/\|\| | ✅ CONCAT | ⚠️ Solo \|\| | Usare helpers cross-DB |

**Raccomandazioni:**
- **PostgreSQL**: Pieno supporto, performance ottimali
- **MySQL/MariaDB**: Supportato, NULLS handling emulato (leggero overhead)
- **SQLite**: Supportato, ideale per development/test

### Compatibilità Rails

| Rails Version | BetterModel | Note |
|---------------|-------------|------|
| **8.1+** | ✅ Completo | Versione minima richiesta |
| **8.0** | ⚠️ Non testato | Potrebbe funzionare ma non garantito |
| **7.x** | ❌ Non supportato | ActiveModel::Attributes API differente |

### Naming Pattern StateMachine - Zero Conflitti

BetterModel::StateMachine usa un **naming pattern esplicito** per evitare conflitti con Rails built-in methods, colonne booleane, enum, e gem di terze parti:

| Tipo | Pattern | Esempio | Evita conflitto con |
|------|---------|---------|---------------------|
| **State check** | `in_#{state}?` | `in_published?` | Colonne booleane `published?`, Rails enum, scope |
| **Transition** | `to_#{state}!` | `to_published!` | Metodi custom, business logic methods |
| **Can check** | `can_to_#{state}?` | `can_to_published?` | Authorization gems (Pundit, CanCanCan) |
| **Previous state** | `was_#{state}?` | `was_draft?` | Helper user-friendly basato su `status_was` Rails |

**Esempi Comparativi:**

```ruby
# ❌ VECCHIO APPROCCIO (conflitti potenziali)
article.published?           # Conflitto con colonna boolean :published
article.publish!             # Conflitto con metodo custom publish!
article.can_publish?         # Conflitto con Pundit policy

# ✅ NUOVO APPROCCIO (zero conflitti)
article.in_published?        # Chiaro: "è nello stato published?"
article.to_published!        # Chiaro: "vai allo stato published"
article.can_to_published?    # Chiaro: "può transizionare a published?"
article.was_draft?           # Chiaro: "era nello stato draft?"
```

**Benefici:**
- ✅ Zero conflitti con Rails enum, colonne booleane, scope
- ✅ Semantica chiara: `in_*` indica stato corrente, `to_*` indica azione
- ✅ API consistente e prevedibile
- ✅ Future-proof: naming pattern distintivo da Rails core
- ✅ Helper `was_*` più user-friendly che accedere a `status_was`

**Nota per stati con underscore:**
Stati come `:in_review` generano metodi come `status == 'in_review'` per evitare `in_in_review?`. Raccomandato usare confronto diretto o stati senza underscore.

### Conflitti con Gems Comuni

#### 1. Rails Enum (Built-in)

**Conflitto:** Il metodo `status_checks` di Statusable originariamente si chiamava `statuses`, che confliggeva con Rails enum.

```ruby
# ❌ CONFLITTO - Non usare insieme
class Article < ApplicationRecord
  include BetterModel::Statusable
  enum status: [:draft, :published]  # Genera .statuses class method
end

# ✅ RISOLTO - Statusable usa status_checks
class Article < ApplicationRecord
  include BetterModel::Statusable
  enum status: [:draft, :published]

  is :publishable, -> { draft? && valid? }
end

article.statuses         # => Rails enum mapping
article.status_checks    # => Statusable stati derivati
```

#### 2. Devise (Authentication)

**Conflitto:** EmailType transformation con Devise email handling.

```ruby
# ⚠️ POTENZIALE CONFLITTO
class User < ApplicationRecord
  include BetterModel::Attributes
  email_attribute :email  # Applica .downcase transformation
  devise :database_authenticatable, :registerable
end

# ✅ SOLUZIONE - Usa attributo standard per Devise
class User < ApplicationRecord
  # NON usare email_attribute per campi gestiti da Devise
  devise :database_authenticatable, :registerable

  # Usa BetterModel per altri campi
  email_attribute :recovery_email  # OK per campi non-Devise
end
```

#### 3. Ransack / Searchkick

**Conflitto:** Searchable sostituisce Ransack, nomi scope potrebbero confliggere.

```ruby
# ❌ NON MESCOLARE
class Article < ApplicationRecord
  include BetterModel::Searchable  # Genera _eq, _in, _cont scopes
  # E NON usare Ransack - confliggeranno
end

# ✅ SCEGLI UNO
# Opzione A: Solo BetterModel
class Article < ApplicationRecord
  include BetterModel::Searchable
  define_auto_predicates :title, :status
end

# Opzione B: Solo Ransack
class Article < ApplicationRecord
  # Usa ransackable_attributes, ecc.
end
```

#### 4. Pundit / CanCanCan (Authorization)

**Conflitto:** Naming convention simili ma semantica diversa.

```ruby
# ⚠️ POTREBBE CONFONDERE
class User < ApplicationRecord
  include BetterModel::Statusable

  is :admin, -> { role == 'admin' }  # Genera is_admin?
end

# Pundit potrebbe avere can_admin? o admin?
# ✅ USA NAMING DISTINTIVO
class User < ApplicationRecord
  include BetterModel::Statusable

  is :has_admin_role, -> { role == 'admin' }  # Più chiaro
end
```

#### 5. AASM / state_machines gem

**Conflitto:** State machine APIs diverse.

```ruby
# ❌ NON MESCOLARE - Conflitti sui metodi di transizione
class Order < ApplicationRecord
  include BetterModel::StateMachine  # Usa questo
  # include AASM  # ❌ Potrebbero esserci conflitti anche con naming diverso
end

# ✅ SCEGLI UNO
# BetterModel::StateMachine è integrato, nessuna dipendenza esterna
```

#### 6. ActsAsTaggable

**Conflitto:** Auto-generated scopes su campo `tags`.

```ruby
# ⚠️ POSSIBILE CONFLITTO
class Article < ApplicationRecord
  include BetterModel::Searchable
  acts_as_taggable_on :tags

  define_auto_predicates :tags  # ❌ Potrebbe confliggere
end

# ✅ ESCLUDI CAMPI GESTITI DA ALTRE GEMS
class Article < ApplicationRecord
  include BetterModel::Searchable
  acts_as_taggable_on :tags

  # Genera predicati solo per campi gestiti da BetterModel
  define_auto_predicates :title, :content, :status
end
```

### Ordine di Inclusione Concerns

**Regola Generale:** Includere concerns in questo ordine per evitare conflitti:

```ruby
class Article < ApplicationRecord
  # 1. Attributes PRIMO (definisce tipi)
  include BetterModel::Attributes

  # 2. Validations (dipende da Attributes)
  include BetterModel::Validations

  # 3. StateMachine (indipendente)
  include BetterModel::StateMachine

  # 4. Statusable (indipendente)
  include BetterModel::Statusable

  # 5. Searchable & Orderable (richiedono ActiveRecord, possono essere in qualsiasi ordine)
  include BetterModel::Searchable
  include BetterModel::Orderable

  # 6. Altri concerns custom
  include MyCustomConcern
end
```

### Thread Safety

Tutti i concerns sono **thread-safe** con le seguenti precauzioni:

1. **Class Attributes**: Immutabili dopo class loading
   ```ruby
   # ✅ SAFE - Definito durante class loading
   state_machine :status do
     states :draft, :published
   end

   # ❌ UNSAFE - Non modificare a runtime
   # self.is_definitions = { new_status: -> { ... } }
   ```

2. **Registry Pattern**: Usa `.freeze` per immutabilità
   ```ruby
   # Già implementato in Statusable
   self.is_definitions = is_definitions.merge(name => condition).freeze
   ```

3. **Singleton Methods**: Creati per istanza, nessun conflitto
   ```ruby
   # Pagination helpers sono sicuri (per-instance)
   results = Article.search({...}, page: 1)
   results.total_count  # Safe, memoized per questa istanza
   ```

### Performance Considerations

| Feature | Overhead | Mitigation | Note |
|---------|----------|------------|------|
| **Auto-predicates** | Basso | Generati a class load | N scopes per M campi |
| **NULLS emulation** | Basso (MySQL) | CASE statement extra | Solo MySQL/MariaDB |
| **Statusable eval** | Medio | Lazy evaluation | Chiamare metodi specifici |
| **Pagination COUNT** | Medio | Memoizzazione ✅ | Ora cached |
| **JSON parsing** | Medio | Usa colonne JSON native | PostgreSQL/MySQL JSON |
| **State transitions** | Basso | Transazioni DB native | Overhead transazionale standard |

### Upgrade Path da Altri Gems

#### Da Ransack a BetterModel::Searchable

```ruby
# PRIMA (Ransack)
Article.ransack(title_cont: 'rails', status_in: ['published']).result

# DOPO (BetterModel)
Article.search(title_i_cont: 'rails', status_in: ['published'])
```

**Mapping predicates:**
- `_cont` → `_i_cont` (case insensitive)
- `_eq` → `_eq` (identico)
- `_in` → `_in` (identico)
- `_gteq` → `_gteq` (identico)
- `_lteq` → `_lteq` (identico)

#### Da AASM a BetterModel::StateMachine

```ruby
# PRIMA (AASM)
class Order < ApplicationRecord
  include AASM

  aasm column: :status do
    state :pending, initial: true
    state :paid

    event :pay do
      transitions from: :pending, to: :paid
    end
  end
end

# DOPO (BetterModel)
class Order < ApplicationRecord
  include BetterModel::StateMachine

  state_machine :status do
    states :pending, :paid
    initial :pending

    transition :pay, from: :pending, to: :paid
  end
end
```

### Riepilogo Conflitti Risolti

Tutti i potenziali conflitti identificati sono stati risolti nell'implementation plan:

| Metodo/Feature | Pattern Precedente | Pattern Nuovo | Potenziale Conflitto | Stato | Risoluzione |
|----------------|-------------------|---------------|---------------------|-------|-------------|
| **State check** | `#{state}?` | `in_#{state}?` | Colonne booleane, Rails enum | ✅ RISOLTO | Prefisso `in_` evita tutti i conflitti |
| **Transition** | `#{transition}!` | `to_#{state}!` | Metodi custom, business logic | ✅ RISOLTO | Focus sullo stato destinazione |
| **Can check** | `can_#{transition}?` | `can_to_#{state}?` | Authorization gems | ✅ RISOLTO | Pattern allineato con `to_*` |
| **Previous state** | _(none)_ | `was_#{state}?` | N/A | ✅ NUOVO | Helper user-friendly |
| **Statusable statuses** | `statuses()` | `status_checks()` | Rails enum `.statuses` | ✅ RISOLTO | Rinominato per chiarezza |
| **JSON type** | `:json` | `:better_json` | Rails native JSON type | ✅ RISOLTO | Prefisso evita override |
| **NULLS ordering** | SQL nativo | Adapter-aware | MySQL/MariaDB incompatibilità | ✅ RISOLTO | Fallback automatico CASE |
| **Pagination COUNT** | Non memoizzato | Memoizzato | Performance (query multiple) | ✅ RISOLTO | Caching con `@_total_count` |
| **State transitions** | No transaction | Transaction wrapper | Data consistency | ✅ RISOLTO | Rollback automatico |
| **ActiveRecord deps** | Nessun check | Validation error | Crash con ActiveModel | ✅ RISOLTO | Raise ArgumentError se non AR |

**Legenda:**
- ✅ RISOLTO: Implementato e documentato nel piano
- ✅ NUOVO: Feature aggiuntiva per migliorare UX

**Zero Conflitti Garantiti:**
Con il nuovo naming pattern (`in_*`, `to_*`, `can_to_*`, `was_*`), BetterModel::StateMachine è **completamente compatibile** con:
- Rails enum
- Colonne booleane
- Scope custom
- Gem di authorization (Pundit, CanCanCan)
- Altre state machine gem (se si sceglie di non usare BetterModel)

### Debugging e Troubleshooting

#### Verificare quale concern gestisce un metodo

```ruby
# In Rails console
Article.ancestors  # Vedi ordine inclusion
Article.instance_method(:is_published?).owner        # => BetterModel::Statusable
Article.instance_method(:in_published?).owner        # => BetterModel::StateMachine::Base
Article.instance_method(:to_published!).owner        # => BetterModel::StateMachine::Base
```

#### Logging SQL per performance

```ruby
# config/environments/development.rb
ActiveRecord::Base.logger = Logger.new(STDOUT)

# Vedi query generate da Searchable/Orderable
Article.search(title_eq: 'test').to_sql
```

#### Verificare conflitti scopes

```ruby
# Lista tutti gli scopes
Article.scopes.keys

# Verifica se scope è definito
Article.respond_to?(:title_eq)  # => true/false
```

---

## Reference Completa DSL Methods

Questa sezione fornisce una reference rapida di **tutti i metodi DSL** disponibili in BetterModel per l'uso nei model.

### Quick Reference - Metodi DSL per Concern

| Concern | Metodi DSL Principali | Metodi Auto-generati |
|---------|----------------------|---------------------|
| **Attributes** | 4 metodi | 2-10 per attributo |
| **Validations** | 6 metodi | - |
| **StateMachine** | 5 metodi | 6 per stato |
| **Statusable** | 1 metodo | 6 per stato |
| **Searchable** | 9 metodi + `search()` | ~13 predicati per campo |
| **Orderable** | 6 metodi + 2 scope | 6-7 scope per campo |

---

### 1. ATTRIBUTES - DSL Methods

#### Metodi di Configurazione

```ruby
# Attributo tipizzato custom
typed_attribute :field_name, :type, **options

# Multipli attributi stesso tipo
attributes_of_type :type, :field1, :field2, **options

# Shortcut email con validazione
email_attribute :email, allow_blank: false

# Attributo JSON con schema
json_attribute :metadata, schema: {...}
```

**Tipi disponibili:** `:string`, `:integer`, `:boolean`, `:array`, `:email`, `:url`, `:better_json`

**Metodi instance auto-generati:**
- Boolean: `toggle_#{attribute}!`
- Array: `add_to_#{attribute}(value)`, `remove_from_#{attribute}(value)`

---

### 2. VALIDATIONS - DSL Methods

```ruby
# Presenza (alias espressivo)
required :field1, :field2, message: "custom"

# Stesse validazioni su più attributi
validate_all :field1, :field2, presence: true, length: {min: 3}

# Email validation
validates_email :email, :backup_email, allow_blank: true

# URL validation
validates_url :website, allow_blank: true

# Validazioni per contesto specifico
validates_on :publication do
  required :title, :subtitle
  validates :content, length: {minimum: 100}
end

# Custom validation con block
validates_with_rule :age do
  age.present? && age >= 18
end
```

---

### 3. STATE MACHINE - DSL Methods

```ruby
state_machine :status do
  # Definisce stati disponibili
  states :draft, :in_review, :published, :archived

  # Stato iniziale default
  initial :draft

  # Definisce transizione
  transition :publish,
    from: [:draft, :in_review],
    to: :published,
    if: :ready_to_publish?,
    before: :prepare_for_publication,
    after: :notify_subscribers

  # Sintassi event-based (alternativa)
  event :submit_for_review do
    transition from: :draft, to: :in_review
  end
end
```

**Metodi instance auto-generati:**
- `in_{state}?` - Verifica stato corrente (`in_published?`)
- `was_{state}?` - Verifica stato precedente (`was_draft?`)
- `to_{state}!` - Esegue transizione (`to_published!`)
- `can_to_{state}?` - Verifica possibilità transizione (`can_to_published?`)
- `current_{column}` - Accesso stato corrente (`current_status`)
- `state_transition(column)` - Info transizione `{from: :draft, to: :published}`

---

### 4. STATUSABLE - DSL Methods

```ruby
# Definisce stato derivato da condizioni
is :status_name, -> { condition }

# Esempi:
is :publishable, -> { in_draft? && valid?(:publication) }
is :expired, -> { expires_at < Time.current }
is :editable, -> { in_draft? || status == 'in_review' }
is :visible, -> { in_published? && published_at <= Time.current }
```

**Class methods:**
- `defined_statuses` - Lista stati definiti
- `status_defined?(name)` - Verifica se definito

**Instance methods auto-generati:**
- `is_{status}?` - Verifica stato (`is_expired?`)
- `is?(status)` - Verifica generica (`is?(:expired)`)
- `status_checks` - Hash tutti gli stati `{expired: true, ...}`
- `has_any_status?` - Almeno uno attivo
- `has_all_statuses?([names])` - Tutti attivi
- `active_statuses([names])` - Filtra attivi

---

### 5. SEARCHABLE - DSL Methods

#### Configurazione Predicati

```ruby
# Auto-genera predicati basati su tipo SQL colonna
define_auto_predicates :field1, :field2, :field3

# Predicati specifici per tipo
define_string_predicates :title, :description
define_numeric_predicates :price, :stock, :view_count
define_boolean_predicates :active, :verified
define_date_predicates :published_at, :created_at
define_enum_predicates :status, :priority
define_foreign_key_predicates :author_id, :category_id

# Predicato custom complesso
register_complex_predicate :popular do |relation, days|
  relation
    .where('published_at >= ?', days.days.ago)
    .where('view_count > ?', 100)
end

# Definisci predicati obbligatori per scope (multitenancy)
require_predicates_for_scope :doctor_dashboard, :doctor_id_eq, :organization_id_eq
```

#### Predicati Generati per Tipo

**String/Text:**
`_eq`, `_not_eq`, `_matches`, `_start`, `_end`, `_cont`, `_not_cont`, `_i_cont`, `_not_i_cont`, `_in`, `_not_in`, `_present`, `_blank`, `_null`

**Numeric:**
`_eq`, `_not_eq`, `_lt`, `_lteq`, `_gt`, `_gteq`, `_in`, `_not_in`, `_present`, `_null`

**Boolean:**
`_eq`, `_not_eq`, `_true`, `_false`, `_present`, `_null`

**Date/DateTime:**
`_eq`, `_not_eq`, `_lt`, `_lteq`, `_gt`, `_gteq`, `_in`, `_not_in`, `_present`, `_null`

#### Metodo Search

```ruby
Model.search(
  # 1. HASH PREDICATI (primo parametro)
  {
    field_predicate: value,
    another_predicate: value
  },

  # 2. NAMED PARAMETERS
  page: 1,                    # Numero pagina
  per_page: 20,               # Elementi per pagina (max 100)
  includes: [...],            # Eager loading (array o nested hash)
  joins: [...],               # SQL joins (array o nested hash)
  order: {...},               # SQL ORDER BY (hash multiplo)
  order: ...,                 # Symbol | Hash | Array (formatting specs)
  limit: :default,            # :default | nil | 1 | N
  scope: :default             # Scope di sicurezza (default: nessun controllo)
)
```

**Comportamento `limit`:**
- `:default` - Usa pagination (default)
- `nil` - Ritorna tutti i record, no pagination
- `1` - Ritorna primo record (non relation)
- `N` - Ritorna relation con LIMIT N, no pagination

**Comportamento `scope`:**
- `:default` - Nessun controllo su predicati obbligatori (backward compatible)
- Altro valore - Richiede predicati definiti con `require_predicates_for_scope`
- Solleva `RequiredPredicateError` se predicati mancanti o nil
- **Uso:** Sicurezza multitenancy per garantire filtri obbligatori (es. `doctor_id_eq`)

**Gestione Multipli Parameters:**

```ruby
# Multiple includes (nested)
includes: [
  :author,
  { comments: :user },
  { business_unit: [:user, :department] }
]

# Multiple joins (nested - sintassi Rails)
joins: [
  :author,
  { business_unit: :user },
  { tags: :category }
]

# Multiple order (hash)
order: {
  published_at: :desc,
  view_count: :desc,
  title: :asc
}
```

**Metodi su Risultati Paginati:**
- `results.current_page` - Pagina corrente
- `results.per_page` - Elementi per pagina
- `results.total_count` - Totale record (memoizzato)
- `results.total_pages` - Totale pagine

---

### 6. ORDERABLE - DSL Methods

#### Configurazione Ordinamenti

```ruby
# Auto-genera basato su tipo SQL
define_auto_ordering :field_name

# Multipli campi auto
define_orderable_fields :field1, :field2, :field3

# Specifici per tipo
define_string_ordering :title, :description
define_numeric_ordering :price, :stock
define_date_ordering :published_at, :created_at

# Base (generico)
define_ordering_scope :custom_field
```

#### Scope Generati per Tipo

**String:**
`_asc`, `_desc`, `_direction(dir)`, `_i_asc`, `_i_desc`, `_i_direction(dir)`

**Numeric:**
`_asc`, `_desc`, `_direction(dir)`, `_nulls_last(dir)`, `_nulls_first(dir)`

**Date/DateTime:**
`_asc`, `_desc`, `_direction(dir)`, `_newest`, `_oldest`

#### Scope Built-in

```ruby
# Ordinamento generico sicuro
Model.order_by(:field, 'asc')

# Ordinamento multiplo
Model.multiple_order(
  field1: 'desc',
  field2: 'asc'
)
```

#### Integrazione con Search

```ruby
# Formato A: Symbol (Orderable scope - semantico)
Article.search({...}, order: :published_at_newest)

# Formato B: Hash (Rails standard SQL)
Article.search({...}, order: { published_at: :desc })

# Formato C: Array misto (Orderable + Rails)
Article.search({...}, order: [:published_at_newest, { view_count: :desc }])

# Formato D: Chain scope dopo search
Article.search({...})
  .published_at_newest
  .view_count_nulls_last('desc')
```

**Esempi Completi Formati `order`:**

```ruby
# === FORMATO 1: Symbol (Orderable scope semantico) ===
Article.search({...}, order: :published_at_newest)
Article.search({...}, order: :view_count_desc)
Article.search({...}, order: :title_i_asc)  # Case-insensitive

# === FORMATO 2: Hash (Rails ORDER BY standard) ===
Article.search({...}, order: { published_at: :desc })
Article.search({...}, order: { published_at: :desc, view_count: :asc })

# === FORMATO 3: Array misto (ordinamenti multipli) ===
Article.search({...}, order: [
  :published_at_newest,      # Primary: scope Orderable
  { view_count: :desc },     # Secondary: Rails hash
  { title: :asc }            # Tertiary: alfabetico
])

# === FORMATO 4: String (auto-convertito a Symbol) ===
Article.search({...}, order: 'published_at_newest')
```

---

### Esempio Completo - Tutti i DSL Insieme

```ruby
class Article < ApplicationRecord
  # 1. ATTRIBUTES
  include BetterModel::Attributes
  typed_attribute :metadata, :better_json
  email_attribute :author_email
  attributes_of_type :string, :title, :subtitle

  # 2. VALIDATIONS
  include BetterModel::Validations
  required :title, :content, :author_email
  validates_on :publication do
    required :subtitle, :summary
  end

  # 3. STATE MACHINE
  include BetterModel::StateMachine
  state_machine :status do
    initial :draft
    states :draft, :in_review, :published, :archived

    transition :publish,
      from: [:draft, :in_review],
      to: :published,
      if: :valid_for_publication?,
      after: :notify_subscribers
  end

  # 4. STATUSABLE
  include BetterModel::Statusable
  is :publishable, -> { in_draft? && valid?(:publication) }
  is :visible, -> { in_published? }
  is :stale, -> { updated_at < 1.month.ago }

  # 5. SEARCHABLE
  include BetterModel::Searchable
  define_auto_predicates :title, :content, :status, :published_at, :view_count

  register_complex_predicate :popular do |rel, days|
    rel.where('published_at >= ?', days.days.ago)
       .where('view_count > ?', 100)
  end

  # 6. ORDERABLE
  include BetterModel::Orderable
  define_orderable_fields :title, :published_at, :view_count
end
```

**Uso:**

```ruby
# Search con tutti i parametri
results = Article.search(
  # Predicati
  {
    title_i_cont: 'rails',
    status_in: ['published', 'featured'],
    published_at_gteq: 1.month.ago,
    view_count_gt: 100
  },

  # Parameters
  page: 2,
  per_page: 15,
  includes: [:author, { comments: :user }],
  joins: { business_unit: :user },
  order: :published_at_newest,
  limit: :default
)

# Metodi disponibili
results.current_page           # => 2
results.total_pages            # => 10
results.each { |article| ... }

# State machine
article.in_draft?              # => true
article.to_published!          # => transizione
article.was_draft?             # => true

# Statusable
article.is_visible?            # => true
article.status_checks          # => {publishable: false, visible: true, ...}
```

---

### Pattern Comuni

#### Pattern 0: Sicurezza Multitenancy con Scope

```ruby
class Booking < ApplicationRecord
  include BetterModel::Searchable

  # Definisci predicati auto-generati
  define_auto_predicates :doctor_id, :patient_id, :organization_id, :status, :date

  # SICUREZZA: definisci predicati obbligatori per scope specifici
  require_predicates_for_scope :doctor_dashboard, :doctor_id_eq, :organization_id_eq
  require_predicates_for_scope :patient_dashboard, :patient_id_eq, :organization_id_eq
  require_predicates_for_scope :admin_dashboard, :organization_id_eq
end

# Controller - Doctor Dashboard
class Doctor::BookingsController < ApplicationController
  def index
    # ✅ SICURO: scope garantisce filtro per doctor e organization
    @bookings = Booking.search(
      {
        doctor_id_eq: current_doctor.id,
        organization_id_eq: current_organization.id,
        status_eq: params[:status]
      },
      scope: :doctor_dashboard,
      page: params[:page],
      per_page: 20
    )
  rescue BetterModel::Searchable::RequiredPredicateError => e
    # Gestione errore se predicati obbligatori mancanti
    Rails.logger.error "Missing required predicates: #{e.missing_predicates.join(', ')}"
    render json: { error: 'Invalid search parameters' }, status: :bad_request
  end
end

# ❌ Errore di sicurezza - predicati mancanti
Booking.search({ status_eq: 'pending' }, scope: :doctor_dashboard)
# => RequiredPredicateError: "Required predicates missing for scope 'doctor_dashboard': doctor_id_eq, organization_id_eq"

# ❌ Errore - predicato nil (come non passato)
Booking.search(
  { doctor_id_eq: nil, organization_id_eq: 456, status_eq: 'pending' },
  scope: :doctor_dashboard
)
# => RequiredPredicateError: "Required predicates missing for scope 'doctor_dashboard': doctor_id_eq"

# ✅ Funziona - tutti i predicati obbligatori presenti e non-nil
Booking.search(
  { doctor_id_eq: 123, organization_id_eq: 456, status_eq: 'pending' },
  scope: :doctor_dashboard
)
# => ActiveRecord::Relation con risultati filtrati

# ✅ Backward compatible - scope :default non richiede predicati
Booking.search({ status_eq: 'pending' })
# oppure
Booking.search({ status_eq: 'pending' }, scope: :default)
# => Funziona normalmente senza controlli
```

**Vantaggi:**
- **Sicurezza multitenancy garantita:** Impossibile dimenticare filtri critici
- **Errore esplicito:** `RequiredPredicateError` indica esattamente cosa manca
- **Backward compatible:** `scope: :default` mantiene comportamento originale
- **Flessibile:** Diversi scope per diversi contesti (doctor, patient, admin)
- **Predicati multipli:** Supporta array di predicati obbligatori per scope

---

#### Pattern 1: Controller con Search Dinamico

```ruby
class ArticlesController < ApplicationController
  SORT_OPTIONS = {
    'newest' => :published_at_newest,
    'oldest' => :published_at_oldest,
    'popular' => :view_count_desc
  }.freeze

  def index
    @articles = Article.search(
      build_search_params,
      page: params[:page],
      per_page: 20,
      includes: [:author, :tags],
      order: SORT_OPTIONS[params[:sort]] || :published_at_newest
    )
  end

  private

  def build_search_params
    {
      title_i_cont: params[:q],
      status_eq: 'published',
      published_at_gteq: filter_date
    }.compact
  end

  def filter_date
    case params[:timeframe]
    when 'week' then 1.week.ago
    when 'month' then 1.month.ago
    end
  end
end
```

#### Pattern 2: Nested Associations Complex

```ruby
Order.search(
  {
    status_in: ['processing', 'completed'],
    total_gteq: 100
  },
  includes: [
    :customer,
    { line_items: [:product, :variant] },
    { business_unit: [:user, :department] }
  ],
  joins: { business_unit: :user },
  order: { created_at: :desc, total: :desc }
).where(
  business_units: { active: true },
  users: { verified: true }
)
```

#### Pattern 3: Export Senza Pagination

```ruby
# Per CSV/PDF export - tutti i record
all_data = Article.search(
  { created_at_gteq: 1.year.ago },
  limit: nil,  # ← Disabilita pagination
  order: { created_at: :asc }
)

CSV.generate do |csv|
  all_data.find_each do |article|
    csv << [article.title, article.created_at]
  end
end
```

#### Pattern 4: Top N Results

```ruby
# Dashboard widgets
popular = Article.search(
  { status_eq: 'published' },
  limit: 10,  # ← Limite fisso
  order: { view_count: :desc }
)
```

---

### Tabella Quick Reference - Parametri Search

| Parametro | Tipo | Cosa fa | Esempio |
|-----------|------|---------|---------|
| **predicates** | Hash | Predicati di ricerca | `{title_eq: 'foo'}` |
| **page** | Integer | Numero pagina | `page: 2` |
| **per_page** | Integer | Elementi per pagina (max 100) | `per_page: 20` |
| **includes** | Array/Hash | Eager loading | `[:author, {comments: :user}]` |
| **joins** | Array/Hash | SQL JOIN | `{business_unit: :user}` |
| **order** | Hash | SQL ORDER BY | `{published_at: :desc}` |
| **order_scope** | Symbol | Scope Orderable (**priorità**) | `:published_at_newest` |
| **limit** | Symbol/Integer | Limite risultati | `:default` / `nil` / `1` / `N` |

**IMPORTANTE:**
- `order_scope` ha **PRIORITÀ ASSOLUTA** su `order`
- `includes` e `joins` supportano **nested hash** syntax (es. `{business_unit: :user}`)
- `order` supporta **hash multiplo** (es. `{field1: :desc, field2: :asc}`)
- `limit: :default` usa pagination, `limit: nil` ritorna tutti i record

---

## Note di Sviluppo

- Seguire sempre il pattern `ActiveSupport::Concern`
- Ogni modulo deve essere indipendente e includibile singolarmente
- Test coverage minimo: 80%
- Documentare con commenti YARD
- Seguire convenzioni Rails e Ruby style guide (rubocop-rails-omakase)
- Mantenere backward compatibility con Rails 8.1+

---

## Estensioni Future

- Supporto per tipi custom aggiuntivi (phone, currency, etc.)
- Integration con dry-types per type safety avanzato
- Generatori Rails per scaffold con BetterModel
- Dashboard per visualizzare state machines
- Audit log per tracking state transitions
- Supporto per state machines parallele
- Webhooks per state transitions
