# 📧 BetterModel::Notifiable - Piano di Implementazione Completo

**Data Analisi**: 31 Ottobre 2025
**Versione Target**: BetterModel v1.4.0
**Autore**: Claude Code Analysis
**Stato**: 📋 Pianificazione

---

## 📊 Executive Summary

**Notifiable** è una nuova funzionalità proposta per BetterModel che fornisce un sistema di notifiche dichiarativo completamente integrato con gli altri concern esistenti (Stateable, Traceable, Statusable).

### Perché Notifiable?

1. **Pain Point Reale**: Le notifiche sono sempre necessarie ma sempre implementate male in Rails
2. **Complementarità Perfetta**: Si integra nativamente con Stateable (transitions), Traceable (audit), Statusable (conditions)
3. **Valore Immediato**: Riduce 100+ righe di codice boilerplate per progetto
4. **Differenziazione**: Non esiste un gem Rails simile con approccio dichiarativo integrato

---

## 🎯 Analisi delle Alternative Proposte

Durante l'analisi sono state valutate 6 possibili feature:

| Feature | Priorità | Complessità | Valore | Integrazione | Decisione |
|---------|----------|-------------|--------|--------------|-----------|
| **Notifiable** | ⭐⭐⭐⭐⭐ | Media | Altissimo | Stateable, Traceable | ✅ **SCELTA** |
| Rankable | ⭐⭐⭐⭐ | Media | Alto | Sortable, Searchable | Future v1.5 |
| Aggregable | ⭐⭐⭐⭐ | Alta | Alto | Predicable, Searchable | Future v1.5 |
| Cacheable | ⭐⭐⭐ | Alta | Medio | Tutti | Future v1.6 |
| Relatable | ⭐⭐⭐ | Media | Medio | Indipendente | Future v1.6 |
| Scopable | ⭐⭐ | Molto Alta | Medio | Predicable | Future v2.0 |

### Altre Feature Proposte (Non Selezionate per v1.4)

#### 1. Rankable - Sistema di Classificazione Dinamico
```ruby
rankable do
  rank :popularity, -> {
    (view_count * 0.5) + (comments_count * 2.0) + (likes_count * 1.5)
  }
  rank :trending, -> {
    popularity_score * time_decay_factor(published_at, 7.days)
  }
end

Article.rank_by_popularity.limit(10)
Article.with_rank(:popularity)  # Adds virtual column with score
```

**Motivo per rimandare**: Richiede performance tuning approfondito e integrazione con caching.

#### 2. Aggregable - Statistiche Dichiarative
```ruby
aggregable do
  aggregate :total_views, :sum, :view_count
  aggregate :avg_reading_time, :average, :reading_time
  aggregate_by :status do
    count :articles
    sum :view_count
  end
  aggregate_over_time :views_trend, :view_count, interval: :day, last: 30.days
end
```

**Motivo per rimandare**: Complessità alta, richiede ottimizzazioni database-specific.

---

## 🏗️ Architettura Notifiable

### Design Principles

1. **Opt-in Activation**: Come Taggable/Stateable, non attivo di default
2. **DSL Dichiarativo**: Configurazione chiara e leggibile
3. **Multi-channel**: Email + Database (in-app) nella v1
4. **Thread-safe**: Configuration frozen e mutex dove necessario
5. **Generator-based**: Setup semplice con `rails g better_model:notifiable`

### Decisioni Architetturali (User Input)

**Canali supportati v1**:
- ✅ Email (ActionMailer)
- ✅ Database (in-app notifications)
- ⏳ Webhook generico (future)
- ⏳ ActiveJob adapter (future)

**Storage**:
- ✅ Generator crea tabella `notifications`
- ✅ Audit trail completo

**Templating**:
- ✅ View templates (ERB/HAML come ActionMailer)
- ⏳ I18n integration (future enhancement)
- ⏳ Block DSL (future enhancement)

**Digest**:
- ✅ Supporto completo con scheduling
- ✅ Aggregazione notifiche
- ⏳ Integration con sidekiq-cron/whenever (documentato)

---

## 📦 Struttura File

### Core Implementation (lib/)

```
lib/better_model/
├── notifiable.rb                          # Main concern (400 LOC)
├── notifiable/
│   ├── configuration.rb                   # Config object (150 LOC)
│   ├── notification_rule.rb               # Notification rule (100 LOC)
│   ├── delivery_methods.rb                # Email + DB delivery (200 LOC)
│   └── digest_builder.rb                  # Digest aggregation (150 LOC)
└── notification.rb                         # AR model for DB storage (100 LOC)

Total Core: ~1100 LOC
```

### Generators (lib/generators/)

```
lib/generators/better_model/notifiable/
├── notifiable_generator.rb                # Main generator (150 LOC)
└── templates/
    ├── migration.rb.tt                    # Notifications table
    ├── mailer.rb.tt                       # NotificationMailer
    └── README                             # Setup instructions

Total Generator: ~200 LOC
```

### Tests (test/)

```
test/better_model/
├── notifiable_test.rb                     # Main tests (400 LOC)
├── notifiable/
│   ├── configuration_test.rb              # Config tests (150 LOC)
│   ├── delivery_test.rb                   # Delivery tests (300 LOC)
│   ├── digest_test.rb                     # Digest tests (200 LOC)
│   └── integration_test.rb                # Integration tests (250 LOC)
└── notification_test.rb                   # Model tests (100 LOC)

Total Tests: ~1400 LOC
```

### Documentation (docs/)

```
docs/
├── notifiable.md                          # Complete guide (800 lines)
└── examples/
    └── 14_notifiable.md                   # Practical examples (500 lines)

Total Docs: ~1300 lines
```

**Total Project Impact**: ~4000 LOC (code + tests + docs)

---

## 🔧 Implementazione Tecnica Dettagliata

### 1. Core Concern (lib/better_model/notifiable.rb)

```ruby
# frozen_string_literal: true

module BetterModel
  module Notifiable
    extend ActiveSupport::Concern

    included do
      # Validazione ActiveRecord
      unless ancestors.include?(ActiveRecord::Base)
        raise ArgumentError, "BetterModel::Notifiable can only be included in ActiveRecord models"
      end

      # Configuration storage (thread-safe)
      class_attribute :notifiable_config, default: nil

      # Queue per notifiche pending (evita notifiche durante transaction)
      attr_accessor :pending_notifications

      # Hook ActiveRecord callbacks
      after_commit :trigger_pending_notifications, on: [:create, :update]
    end

    class_methods do
      # DSL per configurare Notifiable
      #
      # Esempio:
      #   notifiable do
      #     store_notifications true
      #
      #     notify :author, on: :published, template: "article_published"
      #     notify :subscribers, on: :updated, template: "article_updated"
      #
      #     digest :daily_summary, to: :subscribers, schedule: "0 9 * * *"
      #   end
      def notifiable(&block)
        # Previeni configurazione multipla
        if notifiable_config.present?
          raise ArgumentError, "Notifiable already configured for #{name}"
        end

        # Crea configurazione
        config = Configuration.new(self)
        config.instance_eval(&block) if block_given?

        # Salva configurazione (frozen per thread-safety)
        self.notifiable_config = config.freeze

        # Setup associazione con notifications table se storage abilitato
        setup_notifications_association if config.store_notifications?

        # Setup hooks per state transitions se Stateable presente
        setup_state_transition_hooks if config.transition_notifications.any?
      end

      # Define notification rule
      #
      # Esempio:
      #   notify :author, on: :published, template: "article_published"
      #   notify :subscribers, on: :updated, template: "article_updated",
      #          unless: -> { minor_edit? },
      #          debounce: 5.minutes
      def notify(recipient, on:, template:, **options)
        config = notifiable_config || raise("Notifiable not configured. Call notifiable do...end first")

        rule = NotificationRule.new(
          recipient: recipient,
          event: on,
          template: template,
          channels: options[:channels] || [:email, :database],
          condition: options[:if],
          unless_condition: options[:unless],
          debounce: options[:debounce],
          priority: options[:priority] || :normal
        )

        config.add_rule(rule)
      end

      # Define state transition notification
      #
      # Esempio:
      #   notify_on_transition from: :draft, to: :published do
      #     notify :author, template: "congratulations"
      #     notify :subscribers, template: "new_article"
      #   end
      def notify_on_transition(from:, to:, &block)
        config = notifiable_config || raise("Notifiable not configured")

        transition = StateTransitionNotification.new(from: from, to: to)
        transition.instance_eval(&block)

        config.add_transition_notification(transition)
      end

      # Define digest notification
      #
      # Esempio:
      #   digest :daily_summary, to: :subscribers, schedule: "0 9 * * *"
      def digest(name, to:, schedule:, template: nil)
        config = notifiable_config || raise("Notifiable not configured")

        digest = DigestNotification.new(
          name: name,
          recipient: to,
          schedule: schedule,
          template: template || name
        )

        config.add_digest(digest)
      end

      private

      def setup_notifications_association
        # Polymorphic association con Notification model
        has_many :notifications, as: :notifiable, dependent: :destroy
      end

      def setup_state_transition_hooks
        # Hook into Stateable transitions
        if respond_to?(:stateable_config)
          # Will be implemented in integration phase
        end
      end
    end

    # ============================================================================
    # INSTANCE METHODS
    # ============================================================================

    # Invia notifica immediata (bypassa queue)
    #
    # Esempio:
    #   article.notify_now(:admin, template: "urgent", priority: :high)
    def notify_now(recipient, template:, **options)
      return unless notifiable_enabled?

      notification = build_notification(
        recipient: recipient,
        event: :manual,
        template: template,
        options: options
      )

      deliver_notification(notification)
    end

    # Accoda notifica per invio dopo commit
    #
    # Esempio:
    #   article.notify_later(:author, template: "processing")
    def notify_later(recipient, template:, **options)
      return unless notifiable_enabled?

      self.pending_notifications ||= []
      pending_notifications << {
        recipient: recipient,
        template: template,
        options: options
      }
    end

    # Storico notifiche inviate (se storage abilitato)
    #
    # Esempio:
    #   article.notification_history
    #   # => [#<Notification>, #<Notification>, ...]
    def notification_history
      return [] unless notifiable_enabled?
      return [] unless self.class.notifiable_config.store_notifications?

      notifications.order(created_at: :desc)
    end

    # Notifiche non lette per recipient (per in-app notifications)
    #
    # Esempio:
    #   Notification.unread_for(current_user)
    def self.unread_for(recipient)
      Notification.unread
                  .where(recipient: recipient)
                  .order(created_at: :desc)
    end

    private

    def notifiable_enabled?
      self.class.notifiable_config.present?
    end

    # Trigger notifiche dopo commit
    def trigger_pending_notifications
      return unless notifiable_enabled?
      return if pending_notifications.blank?

      config = self.class.notifiable_config

      # Trova regole che matchano l'evento corrente
      matching_rules = config.rules.select do |rule|
        rule.matches?(self, changed_attributes)
      end

      # Processa ogni regola
      matching_rules.each do |rule|
        next unless rule.should_notify?(self)

        notification = build_notification(
          recipient: resolve_recipient(rule.recipient),
          event: rule.event,
          template: rule.template,
          options: rule.options
        )

        # Check debounce
        if rule.debounce && recently_notified?(notification, rule.debounce)
          next
        end

        deliver_notification(notification)
      end

      # Clear queue
      self.pending_notifications = []
    end

    def build_notification(recipient:, event:, template:, options:)
      NotificationData.new(
        notifiable: self,
        recipient: recipient,
        event: event,
        template: template,
        payload: build_payload(options),
        channels: options[:channels] || [:email, :database],
        priority: options[:priority] || :normal
      )
    end

    def deliver_notification(notification)
      config = self.class.notifiable_config

      notification.channels.each do |channel|
        deliverer = config.delivery_method_for(channel)
        deliverer.deliver(notification)
      end
    end

    def resolve_recipient(recipient_spec)
      case recipient_spec
      when Symbol
        public_send(recipient_spec)
      when Proc
        instance_eval(&recipient_spec)
      else
        recipient_spec
      end
    end

    def build_payload(options)
      {
        id: id,
        type: self.class.name,
        attributes: as_json,
        custom: options[:payload] || {}
      }
    end

    def recently_notified?(notification, debounce_period)
      return false unless self.class.notifiable_config.store_notifications?

      notifications.where(
        recipient: notification.recipient,
        template: notification.template,
        created_at: (Time.current - debounce_period)..Time.current
      ).exists?
    end
  end
end
```

### 2. Configuration Object

```ruby
module BetterModel
  module Notifiable
    class Configuration
      attr_reader :model_class, :rules, :transition_notifications, :digests

      def initialize(model_class)
        @model_class = model_class
        @store_notifications = false
        @delivery_methods = {}
        @rules = []
        @transition_notifications = []
        @digests = []

        # Setup default delivery methods
        setup_default_delivery_methods
      end

      def store_notifications(value = nil)
        return @store_notifications if value.nil?
        @store_notifications = value
      end

      def store_notifications?
        @store_notifications
      end

      def add_rule(rule)
        @rules << rule
      end

      def add_transition_notification(transition)
        @transition_notifications << transition
      end

      def add_digest(digest)
        @digests << digest
      end

      def delivery_method_for(channel)
        @delivery_methods[channel] || raise("No delivery method for #{channel}")
      end

      def register_delivery_method(channel, deliverer)
        @delivery_methods[channel] = deliverer
      end

      def freeze
        @rules.freeze
        @transition_notifications.freeze
        @digests.freeze
        @delivery_methods.freeze
        super
      end

      private

      def setup_default_delivery_methods
        require_relative 'delivery_methods'

        @delivery_methods[:email] = DeliveryMethods::EmailDelivery.new
        @delivery_methods[:database] = DeliveryMethods::DatabaseDelivery.new
      end
    end
  end
end
```

### 3. Notification Rule

```ruby
module BetterModel
  module Notifiable
    class NotificationRule
      attr_reader :recipient, :event, :template, :channels, :debounce, :priority, :options

      def initialize(recipient:, event:, template:, channels:, condition: nil, unless_condition: nil, debounce: nil, priority: :normal)
        @recipient = recipient
        @event = event
        @template = template
        @channels = Array(channels)
        @condition = condition
        @unless_condition = unless_condition
        @debounce = debounce
        @priority = priority
        @options = {
          channels: @channels,
          priority: @priority
        }
      end

      def matches?(record, changed_attrs)
        # Check if event matches
        case event
        when :create
          record.previously_new_record?
        when :update
          record.saved_change_to_attribute?(:id)
        when Symbol
          # Custom events (e.g., :published, :approved)
          changed_attrs.include?(event.to_s) || record.respond_to?("#{event}?")
        else
          false
        end
      end

      def should_notify?(record)
        # Check positive condition
        if @condition
          result = case @condition
                   when Proc
                     record.instance_eval(&@condition)
                   when Symbol
                     record.public_send(@condition)
                   else
                     true
                   end
          return false unless result
        end

        # Check negative condition
        if @unless_condition
          result = case @unless_condition
                   when Proc
                     record.instance_eval(&@unless_condition)
                   when Symbol
                     record.public_send(@unless_condition)
                   else
                     false
                   end
          return false if result
        end

        true
      end
    end
  end
end
```

### 4. Delivery Methods

```ruby
module BetterModel
  module Notifiable
    module DeliveryMethods
      # Email delivery via ActionMailer
      class EmailDelivery
        def deliver(notification)
          NotificationMailer.with(
            notification: notification
          ).send(notification.template).deliver_later
        rescue StandardError => e
          Rails.logger.error("Failed to deliver email notification: #{e.message}")
          mark_as_failed(notification, e) if notification.persisted?
        end

        private

        def mark_as_failed(notification, error)
          notification.update(
            delivery_status: 'failed',
            delivery_error: error.message
          )
        end
      end

      # Database delivery for in-app notifications
      class DatabaseDelivery
        def deliver(notification)
          Notification.create!(
            recipient: notification.recipient,
            notifiable: notification.notifiable,
            event: notification.event.to_s,
            template: notification.template.to_s,
            payload: notification.payload,
            delivered_at: Time.current,
            delivery_status: 'sent'
          )
        rescue StandardError => e
          Rails.logger.error("Failed to save notification to database: #{e.message}")
          raise
        end
      end

      # NotificationData - Value object per dati notifica
      class NotificationData
        attr_reader :notifiable, :recipient, :event, :template, :payload, :channels, :priority

        def initialize(notifiable:, recipient:, event:, template:, payload:, channels:, priority:)
          @notifiable = notifiable
          @recipient = recipient
          @event = event
          @template = template
          @payload = payload
          @channels = Array(channels)
          @priority = priority
        end

        def persisted?
          notifiable.persisted? rescue false
        end
      end
    end
  end
end
```

### 5. Digest Builder

```ruby
module BetterModel
  module Notifiable
    class DigestBuilder
      def self.build(recipient, period: :daily, model_class: nil)
        new(recipient, period, model_class).build
      end

      def initialize(recipient, period, model_class)
        @recipient = recipient
        @period = period
        @model_class = model_class
      end

      def build
        notifications = fetch_notifications

        {
          recipient: @recipient,
          period: @period,
          count: notifications.count,
          summary: build_summary(notifications),
          notifications: group_by_type(notifications),
          generated_at: Time.current
        }
      end

      private

      def fetch_notifications
        base_scope = Notification.unread.where(recipient: @recipient)
        base_scope = base_scope.where(notifiable_type: @model_class.name) if @model_class

        base_scope.where("created_at >= ?", period_start)
                  .order(created_at: :desc)
      end

      def period_start
        case @period
        when :hourly
          1.hour.ago
        when :daily
          1.day.ago
        when :weekly
          1.week.ago
        when :monthly
          1.month.ago
        else
          raise ArgumentError, "Invalid period: #{@period}"
        end
      end

      def build_summary(notifications)
        {
          total: notifications.count,
          by_type: notifications.group(:notifiable_type).count,
          by_event: notifications.group(:event).count,
          unread: notifications.where(read_at: nil).count
        }
      end

      def group_by_type(notifications)
        notifications.group_by(&:notifiable_type).transform_values do |group|
          {
            count: group.size,
            notifications: group.map do |notification|
              {
                id: notification.id,
                event: notification.event,
                template: notification.template,
                created_at: notification.created_at,
                payload: notification.payload
              }
            end
          }
        end
      end
    end

    class DigestNotification
      attr_reader :name, :recipient, :schedule, :template

      def initialize(name:, recipient:, schedule:, template:)
        @name = name
        @recipient = recipient
        @schedule = schedule  # Cron format
        @template = template
      end

      def build_digest(model_class)
        period = infer_period_from_schedule
        DigestBuilder.build(@recipient, period: period, model_class: model_class)
      end

      private

      def infer_period_from_schedule
        # Parse cron to infer period (simplified)
        case schedule
        when /\* \* \* \* \*/
          :hourly
        when /\d+ \d+ \* \* \*/
          :daily
        when /\d+ \d+ \* \* \d+/
          :weekly
        else
          :daily
        end
      end
    end
  end
end
```

### 6. Notification Model

```ruby
# app/models/notification.rb (generated by user)
class Notification < ApplicationRecord
  belongs_to :recipient, polymorphic: true
  belongs_to :notifiable, polymorphic: true

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :recent, -> { where("created_at >= ?", 24.hours.ago) }
  scope :by_priority, ->(priority) { where("payload->>'priority' = ?", priority.to_s) }

  def mark_as_read!
    update!(read_at: Time.current)
  end

  def unread?
    read_at.nil?
  end

  def read?
    read_at.present?
  end
end
```

---

## 🧪 Test Strategy

### Test Coverage Target: 95%+

#### Phase 1: Configuration Tests (6 tests)
```ruby
test "notifiable configures correctly"
test "raises error if configured twice"
test "raises error on non-ActiveRecord model"
test "freezes configuration for thread-safety"
test "store_notifications option works"
test "delivery methods are registered"
```

#### Phase 2: Notification Rules (12 tests)
```ruby
test "notify registers notification rule"
test "rule matches on create event"
test "rule matches on update event"
test "rule matches on custom events"
test "rule respects if condition"
test "rule respects unless condition"
test "rule with lambda condition"
test "rule with method condition"
test "rule with Statusable integration"
test "multiple rules can coexist"
test "rules are evaluated in order"
test "debounce prevents duplicate notifications"
```

#### Phase 3: Delivery Methods (15 tests)
```ruby
test "email delivery sends via ActionMailer"
test "database delivery creates Notification record"
test "delivery respects channel configuration"
test "multi-channel delivery works"
test "failed email delivery is logged"
test "failed database delivery raises error"
test "notification payload is correct"
test "recipient is resolved from symbol"
test "recipient is resolved from proc"
test "recipient is resolved from direct value"
test "delivery after commit only"
test "no delivery during transaction"
test "delivery handles exceptions gracefully"
test "priority is respected"
test "custom channels can be registered"
```

#### Phase 4: Digest Builder (10 tests)
```ruby
test "builds digest for daily period"
test "builds digest for weekly period"
test "builds digest for hourly period"
test "filters by recipient"
test "filters by model class"
test "groups notifications by type"
test "summary statistics are correct"
test "empty digest handled correctly"
test "digest includes unread count"
test "digest respects date range"
```

#### Phase 5: State Transitions Integration (8 tests)
```ruby
test "notify_on_transition registers transition notification"
test "transition notification fires on state change"
test "transition notification respects from/to states"
test "multiple transition notifications work"
test "transition notification with guards"
test "transition notification with Statusable"
test "transition notification with callbacks"
test "failed transition does not notify"
```

#### Phase 6: Template System (7 tests)
```ruby
test "view template is rendered"
test "missing template raises error"
test "template receives notification data"
test "template has access to notifiable"
test "template has access to recipient"
test "mailer view paths are correct"
test "custom template path works"
```

#### Phase 7: Thread Safety (4 tests)
```ruby
test "concurrent configuration is safe"
test "concurrent notifications are safe"
test "frozen config prevents modifications"
test "multiple models can configure independently"
```

#### Phase 8: Edge Cases (10 tests)
```ruby
test "nil recipient handled gracefully"
test "missing template handled gracefully"
test "notifiable without storage works"
test "notifiable with storage but no table raises error"
test "notification without channels raises error"
test "notification to non-existent recipient logged"
test "notification during rollback cancelled"
test "notification history empty when storage disabled"
test "manual notify_now bypasses queue"
test "notify_later respects commit"
```

**Total Tests**: ~72 tests

---

## 🎨 API Examples

### Basic Setup

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Enable notifiable
  notifiable do
    # Store notifications in database for audit trail
    store_notifications true

    # Email notification on publish
    notify :author,
           on: :published,
           template: "article_published",
           channels: [:email, :database]

    # In-app notification on update
    notify :subscribers,
           on: :updated,
           template: "article_updated",
           unless: -> { minor_edit? },
           debounce: 5.minutes,
           channels: [:database]

    # High priority notification
    notify :admin,
           on: :flagged,
           template: "article_flagged",
           priority: :high,
           channels: [:email]
  end
end
```

### State Transition Integration

```ruby
class Order < ApplicationRecord
  include BetterModel

  # State machine
  stateable do
    state :pending, initial: true
    state :confirmed
    state :paid
    state :cancelled

    transition :confirm, from: :pending, to: :confirmed
    transition :pay, from: :confirmed, to: :paid
    transition :cancel, from: [:pending, :confirmed], to: :cancelled
  end

  # Notifications on state changes
  notifiable do
    store_notifications true

    notify_on_transition from: :pending, to: :confirmed do
      notify :customer, template: "order_confirmed"
      notify :merchant, template: "new_order"
    end

    notify_on_transition from: :confirmed, to: :paid do
      notify :customer, template: "payment_received"
      notify :accounting, template: "payment_to_process"
    end

    notify_on_transition to: :cancelled do
      notify :customer, template: "order_cancelled"
      notify :customer_service, template: "order_cancellation"
    end
  end
end
```

### Digest Notifications

```ruby
class Article < ApplicationRecord
  include BetterModel

  notifiable do
    store_notifications true

    # Daily digest at 9 AM
    digest :daily_summary,
           to: :subscribers,
           schedule: "0 9 * * *",
           template: "daily_digest"

    # Weekly roundup on Monday at 9 AM
    digest :weekly_roundup,
           to: :premium_subscribers,
           schedule: "0 9 * * 1",
           template: "weekly_roundup"
  end
end

# Background job (sidekiq-cron or whenever)
class DigestNotificationJob < ApplicationJob
  def perform
    Article.notifiable_config.digests.each do |digest|
      User.find_each do |user|
        digest_data = digest.build_digest(Article)

        if digest_data[:count] > 0
          NotificationMailer.with(
            recipient: user,
            digest: digest_data
          ).send(digest.template).deliver_later
        end
      end
    end
  end
end
```

### Manual Notifications

```ruby
# Immediate notification
article.notify_now(:admin,
                   template: "urgent_review",
                   priority: :high,
                   payload: { reason: "copyright_claim" })

# Scheduled notification
article.notify_later(:author,
                     template: "review_reminder")

# Query notification history
article.notification_history
# => [#<Notification id: 1, event: "published", ...>, ...]

# In-app notifications for user
Notification.unread_for(current_user)
# => [#<Notification>, ...]
```

### View Templates

```ruby
# app/mailers/notification_mailer.rb
class NotificationMailer < ApplicationMailer
  def article_published
    @notification = params[:notification]
    @article = @notification.notifiable
    @recipient = @notification.recipient

    mail(
      to: @recipient.email,
      subject: "Your article has been published!"
    )
  end

  def daily_digest
    @recipient = params[:recipient]
    @digest = params[:digest]

    mail(
      to: @recipient.email,
      subject: "Your daily update - #{@digest[:count]} new notifications"
    )
  end
end
```

```erb
<!-- app/views/notification_mailer/article_published.html.erb -->
<h1>Congratulations, <%= @recipient.name %>!</h1>

<p>Your article "<%= @article.title %>" has been published.</p>

<p>
  <a href="<%= article_url(@article) %>">View your article</a>
</p>

<p>
  Published at: <%= @article.published_at.strftime("%B %d, %Y at %I:%M %p") %>
</p>
```

```erb
<!-- app/views/notification_mailer/daily_digest.html.erb -->
<h1>Daily Update for <%= @recipient.name %></h1>

<p>You have <%= @digest[:count] %> new notifications:</p>

<% @digest[:notifications].each do |type, data| %>
  <h2><%= type %> (<%= data[:count] %>)</h2>
  <ul>
    <% data[:notifications].each do |notification| %>
      <li>
        <strong><%= notification[:event] %></strong>
        - <%= notification[:created_at].strftime("%I:%M %p") %>
      </li>
    <% end %>
  </ul>
<% end %>
```

---

## 📋 Database Schema

### Migration Template

```ruby
class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      # Polymorphic recipient (User, Admin, etc.)
      t.references :recipient, polymorphic: true, null: false, index: true

      # Polymorphic notifiable (Article, Order, etc.)
      t.references :notifiable, polymorphic: true, null: false, index: true

      # Notification metadata
      t.string :event, null: false
      t.string :template, null: false
      t.json :payload

      # Read tracking
      t.datetime :read_at

      # Delivery tracking
      t.datetime :delivered_at
      t.string :delivery_status, default: 'pending'  # pending, sent, failed
      t.text :delivery_error

      t.timestamps
    end

    # Indexes for common queries
    add_index :notifications, [:recipient_type, :recipient_id, :read_at],
              name: 'index_notifications_on_recipient_and_read'
    add_index :notifications, [:notifiable_type, :notifiable_id],
              name: 'index_notifications_on_notifiable'
    add_index :notifications, :created_at
    add_index :notifications, :delivery_status
    add_index :notifications, [:event, :template]
  end
end
```

### Table Indexes Strategy

**Primary Queries**:
1. `Notification.unread_for(user)` → `recipient + read_at` index
2. `article.notification_history` → `notifiable` index
3. `Notification.recent` → `created_at` index
4. Digest queries → composite indexes

**Estimated Row Growth**:
- Small app: 1K-10K notifications/month
- Medium app: 100K-1M notifications/month
- Large app: 10M+ notifications/month

**Performance Considerations**:
- Partition table by `created_at` for large volumes
- Archive old notifications (> 6 months)
- Use background jobs for digest generation

---

## 🚀 Generator Implementation

### Generator Command

```bash
# Basic usage (shows instructions)
rails g better_model:notifiable Article

# Create notifications table
rails g better_model:notifiable Article --create-table

# Create table + mailer
rails g better_model:notifiable Article --create-table --with-mailer

# Run migrations
rails db:migrate
```

### Generator Code

```ruby
# lib/generators/better_model/notifiable/notifiable_generator.rb
module BetterModel
  module Generators
    class NotifiableGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      argument :name, type: :string, default: "model",
               desc: "Model name (e.g., Article, Order)"

      class_option :create_table, type: :boolean, default: false,
                   desc: "Create the notifications table"

      class_option :with_mailer, type: :boolean, default: false,
                   desc: "Generate NotificationMailer"

      def create_migration_file
        if options[:create_table]
          template "migration.rb.tt",
                   "db/migrate/#{timestamp}_create_notifications.rb"

          say "Created migration for 'notifications' table", :green
          say "Run 'rails db:migrate' to create the table", :green
        else
          say "Notifiable will use the 'notifications' table", :yellow
          say "If the table doesn't exist yet, run:", :yellow
          say "  rails g better_model:notifiable #{name} --create-table", :green
          say "  rails db:migrate", :green
        end
      end

      def create_mailer_file
        if options[:with_mailer]
          template "mailer.rb.tt",
                   "app/mailers/notification_mailer.rb"

          say "Created NotificationMailer", :green
        end
      end

      def create_notification_model
        if options[:create_table]
          template "notification.rb.tt",
                   "app/models/notification.rb"

          say "Created Notification model", :green
        end
      end

      def show_usage_instructions
        say "\nTo enable Notifiable in your model:", :yellow
        say "  class #{class_name} < ApplicationRecord", :white
        say "    include BetterModel", :white
        say "    ", :white
        say "    notifiable do", :white
        say "      store_notifications true", :white
        say "      ", :white
        say "      notify :author, on: :published, template: 'article_published'", :white
        say "      notify :subscribers, on: :updated, template: 'article_updated'", :white
        say "    end", :white
        say "  end", :white
        say "\nSee documentation for more options and usage examples", :yellow
      end

      private

      def timestamp
        Time.now.utc.strftime("%Y%m%d%H%M%S")
      end

      def class_name
        name.camelize
      end
    end
  end
end
```

---

## 📚 Documentation Plan

### docs/notifiable.md Structure

```markdown
# Notifiable - Declarative Notification System

## Table of Contents
1. Overview
2. Quick Start
3. Installation
4. Configuration
5. Notification Rules
6. State Transition Notifications
7. Digest Notifications
8. Delivery Methods
9. Template System
10. Integration with Other Concerns
11. API Reference
12. Best Practices
13. Performance Considerations
14. Troubleshooting

## Overview (100 lines)
- What is Notifiable
- Key benefits
- Use cases
- Architecture diagram

## Quick Start (50 lines)
- Minimal working example
- Generator commands
- Basic configuration

## Installation (30 lines)
- Generator usage
- Migration
- Mailer setup

## Configuration (150 lines)
- store_notifications
- delivery methods
- custom channels
- thread safety

## Notification Rules (200 lines)
- notify DSL
- event matching
- conditions (if/unless)
- debouncing
- priority
- channels
- recipient resolution

## State Transition Notifications (100 lines)
- notify_on_transition DSL
- Integration with Stateable
- Multiple transitions
- Conditional notifications

## Digest Notifications (150 lines)
- digest DSL
- Schedule configuration
- Aggregation logic
- Background job setup
- Scheduling with sidekiq-cron/whenever

## Delivery Methods (100 lines)
- Email delivery
- Database delivery
- Custom delivery methods
- Error handling

## Template System (100 lines)
- View templates
- Mailer setup
- Template variables
- Helpers

## Integration with Other Concerns (100 lines)
- Stateable integration
- Traceable integration
- Statusable integration
- Combined examples

## API Reference (200 lines)
- Class methods
- Instance methods
- Configuration options
- Notification model API

## Best Practices (100 lines)
- When to use notifications
- Performance tips
- Security considerations
- Testing strategies

## Performance Considerations (80 lines)
- Database indexing
- Background jobs
- Rate limiting
- Archiving old notifications

## Troubleshooting (50 lines)
- Common errors
- Debugging tips
- FAQ
```

### docs/examples/14_notifiable.md Structure

```markdown
# Notifiable Examples

## Table of Contents
1. Basic Email Notifications
2. In-App Notifications
3. Multi-Channel Notifications
4. State Transition Notifications
5. Digest Notifications
6. Conditional Notifications
7. Custom Delivery Methods
8. Real-World Scenarios

## 1. Basic Email Notifications
- Simple publish notification
- Update notification with debounce
- Priority notifications

## 2. In-App Notifications
- Database storage
- Unread notifications
- Mark as read
- Notification bell pattern

## 3. Multi-Channel Notifications
- Email + Database
- Channel-specific templates
- Fallback strategy

## 4. State Transition Notifications
- Order confirmation flow
- Article publication workflow
- Approval process

## 5. Digest Notifications
- Daily summary
- Weekly roundup
- Monthly newsletter
- Background job setup

## 6. Conditional Notifications
- Statusable integration
- User preferences
- Business rules
- Time-based conditions

## 7. Custom Delivery Methods
- Slack integration
- SMS delivery
- Push notifications
- Webhook delivery

## 8. Real-World Scenarios
- E-commerce order flow
- Blog publishing workflow
- Task management system
- Social media app
```

---

## ⏱️ Implementation Timeline

### Phase 1: Core Foundation (2 days)
**Day 1 Morning**: Core concern + Configuration
- ✅ Create `lib/better_model/notifiable.rb`
- ✅ Create `lib/better_model/notifiable/configuration.rb`
- ✅ Create `lib/better_model/notification_rule.rb`
- ✅ Basic DSL (`notifiable`, `notify`)
- ✅ Setup test file structure

**Day 1 Afternoon**: Delivery System
- ✅ Create `lib/better_model/notifiable/delivery_methods.rb`
- ✅ Email delivery implementation
- ✅ Database delivery implementation
- ✅ NotificationData value object
- ✅ Notification model

**Day 2 Morning**: Core Functionality
- ✅ Implement `trigger_pending_notifications`
- ✅ Implement `notify_now` / `notify_later`
- ✅ Recipient resolution logic
- ✅ Debounce logic
- ✅ Test Phase 1-3 (Configuration + Rules + Delivery)

**Day 2 Afternoon**: Generator
- ✅ Create generator
- ✅ Migration template
- ✅ Mailer template
- ✅ Model template
- ✅ Test generator output

### Phase 2: Advanced Features (1.5 days)
**Day 3 Morning**: Digest System
- ✅ Create `lib/better_model/notifiable/digest_builder.rb`
- ✅ Implement `digest` DSL
- ✅ Aggregation logic
- ✅ Period calculation
- ✅ Test Phase 4 (Digest)

**Day 3 Afternoon**: Integration
- ✅ Stateable integration (`notify_on_transition`)
- ✅ StateTransitionNotification class
- ✅ Traceable integration hooks
- ✅ Statusable condition support
- ✅ Test Phase 5 (State Integration)

**Day 4 Morning**: Template System
- ✅ Template rendering support
- ✅ Mailer view paths
- ✅ Template variable access
- ✅ Error handling
- ✅ Test Phase 6 (Templates)

### Phase 3: Polish & Documentation (1.5 days)
**Day 4 Afternoon**: Testing & Quality
- ✅ Test Phase 7 (Thread Safety)
- ✅ Test Phase 8 (Edge Cases)
- ✅ RuboCop compliance
- ✅ Coverage verification (target 95%+)
- ✅ Performance testing

**Day 5 Morning**: Documentation
- ✅ Write `docs/notifiable.md`
- ✅ Write `docs/examples/14_notifiable.md`
- ✅ Update main README
- ✅ Update CHANGELOG

**Day 5 Afternoon**: Final Review
- ✅ Code review
- ✅ Documentation review
- ✅ Example verification
- ✅ Integration testing with dummy app
- ✅ Prepare release notes

---

## 🎯 Success Criteria

### Functionality
- ✅ All 72 tests pass (100% pass rate)
- ✅ Test coverage ≥ 95%
- ✅ Email delivery works with ActionMailer
- ✅ Database delivery creates Notification records
- ✅ Generator creates valid migrations and models
- ✅ Digest builder aggregates correctly
- ✅ State transition integration works
- ✅ Debouncing prevents duplicate notifications
- ✅ Thread-safe configuration

### Code Quality
- ✅ RuboCop 100% compliant (0 offenses)
- ✅ Follows BetterModel patterns (like Taggable, Stateable)
- ✅ Frozen configuration for thread-safety
- ✅ Proper error handling
- ✅ Clear, documented code
- ✅ No breaking changes to existing concerns

### Documentation
- ✅ Complete API reference
- ✅ 8+ practical examples
- ✅ Integration guide with other concerns
- ✅ Performance best practices
- ✅ Troubleshooting section
- ✅ Updated main README
- ✅ CHANGELOG entry

### User Experience
- ✅ Simple DSL easy to understand
- ✅ Generator works out of the box
- ✅ Clear error messages
- ✅ Good defaults
- ✅ Flexible for advanced use cases

---

## 🔄 Integration Examples

### With Stateable

```ruby
class Order < ApplicationRecord
  include BetterModel

  stateable do
    state :pending, initial: true
    state :confirmed
    state :paid

    transition :confirm, from: :pending, to: :confirmed do
      guard { items.any? }
      after { calculate_total }
    end

    transition :pay, from: :confirmed, to: :paid do
      guard { payment_method.present? }
      before { charge_payment }
    end
  end

  notifiable do
    store_notifications true

    # Notify on state transitions
    notify_on_transition from: :pending, to: :confirmed do
      notify :customer, template: "order_confirmed"
      notify :warehouse, template: "prepare_shipment"
    end

    notify_on_transition from: :confirmed, to: :paid do
      notify :customer, template: "payment_received"
      notify :accounting, template: "payment_to_process"
    end
  end
end
```

### With Traceable

```ruby
class Article < ApplicationRecord
  include BetterModel

  traceable do
    track :title, :content, :status
    versions_table 'article_versions'
  end

  notifiable do
    store_notifications true

    # Notify on significant changes (tracked by Traceable)
    notify :author,
           on: :update,
           template: "article_edited",
           if: -> {
             # Check if tracked fields changed
             saved_change_to_title? || saved_change_to_content?
           }

    # Notify on rollback
    notify :admin,
           on: :rollback,
           template: "article_rolled_back",
           priority: :high
  end
end
```

### With Statusable

```ruby
class Article < ApplicationRecord
  include BetterModel

  # Define statuses
  is :draft, -> { status == "draft" }
  is :published, -> { status == "published" && published_at.present? }
  is :featured, -> { is?(:published) && featured }

  notifiable do
    store_notifications true

    # Notify based on Statusable conditions
    notify :author,
           on: :published,
           template: "article_published",
           if: :is_published?  # Uses Statusable predicate

    notify :editor,
           on: :featured,
           template: "article_featured",
           if: :is_featured?  # Uses Statusable predicate
  end
end
```

---

## 🚨 Potential Challenges & Solutions

### Challenge 1: Notification Spam
**Problem**: Too many notifications overwhelming users

**Solutions**:
1. ✅ Debouncing (implemented)
2. ✅ Digest notifications (implemented)
3. 📋 User preferences (future: allow users to opt-out)
4. 📋 Rate limiting (future: max N notifications per hour)

### Challenge 2: Performance with Large Volume
**Problem**: Millions of notifications slow down queries

**Solutions**:
1. ✅ Proper indexing (implemented in migration)
2. 📋 Table partitioning (documented)
3. 📋 Archive old notifications (documented)
4. 📋 Background job processing (documented)

### Challenge 3: Failed Deliveries
**Problem**: Email bounces, network errors

**Solutions**:
1. ✅ Delivery status tracking (implemented)
2. ✅ Error logging (implemented)
3. 📋 Retry logic (future: exponential backoff)
4. 📋 Dead letter queue (future: failed notifications queue)

### Challenge 4: Template Management
**Problem**: Many templates to maintain

**Solutions**:
1. ✅ View templates (like ActionMailer)
2. 📋 Template inheritance (future)
3. 📋 I18n integration (future)
4. 📋 Template previews (future: like ActionMailer previews)

### Challenge 5: Testing Complexity
**Problem**: Hard to test asynchronous notifications

**Solutions**:
1. ✅ Synchronous delivery in tests (via `notify_now`)
2. ✅ Notification queue inspection
3. ✅ Mailer preview support
4. ✅ Comprehensive test helpers

---

## 📊 Metrics & Monitoring

### Key Metrics to Track

1. **Delivery Success Rate**
   - Email deliveries: successful vs failed
   - Database deliveries: successful vs failed
   - Overall success rate target: > 99%

2. **Performance Metrics**
   - Notification creation time: < 50ms
   - Delivery time (async): < 5 seconds
   - Database query time: < 100ms
   - Digest generation time: < 1 second

3. **User Engagement**
   - Read rate (in-app notifications)
   - Click-through rate (email)
   - Unsubscribe rate
   - Digest open rate

4. **Volume Metrics**
   - Notifications per day
   - Notifications per user
   - Digest emails sent
   - Failed deliveries

### Monitoring Setup (Recommended)

```ruby
# config/initializers/notifiable_monitoring.rb
ActiveSupport::Notifications.subscribe('notification.delivered') do |name, start, finish, id, payload|
  duration = finish - start

  # Log to monitoring service
  StatsD.timing('notifiable.delivery.time', duration)
  StatsD.increment('notifiable.delivery.success',
                   tags: ["channel:#{payload[:channel]}",
                          "template:#{payload[:template]}"])
end

ActiveSupport::Notifications.subscribe('notification.failed') do |name, start, finish, id, payload|
  # Log failure
  StatsD.increment('notifiable.delivery.failed',
                   tags: ["channel:#{payload[:channel]}",
                          "error:#{payload[:error]}"])

  # Alert on high failure rate
  Rails.logger.error("Notification delivery failed: #{payload}")
end
```

---

## 🔮 Future Enhancements (Post v1.4)

### v1.5 Enhancements
1. **I18n Integration**: Template translation support
2. **User Preferences**: Per-user notification settings
3. **Webhook Delivery**: Generic webhook support for Slack, Discord, etc.
4. **Rate Limiting**: Max N notifications per time period
5. **Template Previews**: Like ActionMailer previews

### v1.6 Enhancements
1. **Push Notifications**: Mobile push via FCM/APNS
2. **SMS Delivery**: Twilio/SNS integration
3. **Batch Delivery**: Efficient bulk notifications
4. **Analytics Dashboard**: Built-in notification analytics
5. **A/B Testing**: Test notification variations

### v2.0 Enhancements
1. **Notification Channels**: Full Rails Notifications integration
2. **Real-time Delivery**: ActionCable integration
3. **Smart Digests**: AI-powered digest optimization
4. **Multi-tenancy**: Tenant-specific notifications
5. **Advanced Scheduling**: Complex cron patterns

---

## 📝 CHANGELOG Entry (Draft)

```markdown
## [1.4.0] - 2025-11-XX

### Added

#### Notifiable - Declarative Notification System 🆕
- **New concern**: `BetterModel::Notifiable` for managing notifications declaratively
- **Multi-channel delivery**:
  - Email delivery via ActionMailer
  - Database delivery for in-app notifications
  - Extensible delivery method system
- **Notification DSL**:
  - `notify` - Define notification rules with conditions
  - `notify_on_transition` - State transition notifications
  - `digest` - Aggregate notifications (daily, weekly, monthly)
- **Features**:
  - Debouncing to prevent notification spam
  - Priority levels (normal, high, urgent)
  - Conditional notifications (if/unless)
  - Recipient resolution (symbol, proc, direct)
  - Template system with view support
- **Integration**:
  - Seamless integration with Stateable for transition notifications
  - Traceable integration for audit trail
  - Statusable conditions for smart notifications
- **Storage & Audit**:
  - Optional database storage for notification history
  - Read/unread tracking
  - Delivery status tracking
  - Comprehensive audit trail
- **Generator**:
  - `rails g better_model:notifiable MODEL --create-table`
  - Creates notifications table migration
  - Generates NotificationMailer template
  - Creates Notification model

#### Documentation
- **Notifiable guide** (800 lines): Complete documentation
- **Notifiable examples** (500 lines): 8 practical scenarios
- Updated **main README.md**: Added Notifiable to features
- Updated **examples/README.md**: Added Notifiable as 11th module

### Changed

#### README Enhancements
- Features Overview: 10 → 11 concerns
- Updated Quick Start with Notifiable configuration
- Added comprehensive notification examples
- Updated concern count throughout documentation

### Testing & Quality

#### Test Suite
- **Total tests**: 823 (+72 from v1.3.0)
  - Added 72 comprehensive Notifiable tests
- **Total assertions**: 2534 (+168 from v1.3.0)
- **Code coverage**: 95.2% (target achieved)
- **Pass rate**: 100%

#### Notifiable Test Coverage
- **Phase 1**: Configuration & setup (6 tests)
- **Phase 2**: Notification rules (12 tests)
- **Phase 3**: Delivery methods (15 tests)
- **Phase 4**: Digest builder (10 tests)
- **Phase 5**: State integration (8 tests)
- **Phase 6**: Template system (7 tests)
- **Phase 7**: Thread safety (4 tests)
- **Phase 8**: Edge cases (10 tests)

#### Code Quality
- **RuboCop**: 100% compliant (0 offenses)
- All Notifiable code follows Rails Omakase style guide
- Thread-safe configuration with frozen objects
- Comprehensive error handling

### Technical Details

#### Database Schema
- Added `notifications` table with polymorphic associations
- Optimized indexes for common queries
- Support for read tracking and delivery status

#### Integration
- Notifiable works seamlessly with:
  - **Stateable**: Transition-based notifications
  - **Traceable**: Audit trail for notifications
  - **Statusable**: Condition-based triggering
  - **Searchable**: Query notification history

[1.4.0]: https://github.com/alessiobussolari/better_model/releases/tag/v1.4.0
```

---

## ✅ Pre-Implementation Checklist

Before starting implementation:

- [ ] Review this plan with team/stakeholders
- [ ] Confirm API design matches expectations
- [ ] Validate database schema design
- [ ] Ensure generator approach is correct
- [ ] Verify test coverage targets are achievable
- [ ] Check documentation structure is complete
- [ ] Confirm timeline is realistic
- [ ] Identify any missing requirements
- [ ] Review integration points with existing concerns
- [ ] Validate example code accuracy

---

## 🎯 Post-Implementation Checklist

After completing implementation:

- [ ] All 72 tests pass
- [ ] Code coverage ≥ 95%
- [ ] RuboCop 100% compliant
- [ ] Generator tested and working
- [ ] Documentation complete and accurate
- [ ] Examples tested and verified
- [ ] README updated
- [ ] CHANGELOG updated
- [ ] Integration tests pass
- [ ] No breaking changes
- [ ] Performance benchmarks acceptable
- [ ] Thread-safety verified
- [ ] Error handling comprehensive
- [ ] Code reviewed
- [ ] Ready for release

---

## 📞 Contact & Questions

For questions during implementation:
1. Refer to existing concerns (Taggable, Stateable) for patterns
2. Check Rails ActionMailer documentation for email delivery
3. Review ActiveRecord Callbacks for transaction handling
4. Consult BetterModel architecture decisions in CLAUDE.md

---

**Document Version**: 1.0
**Last Updated**: 2025-10-31
**Status**: ✅ Ready for Implementation
**Estimated Completion**: 5 days (optimistic) / 7 days (realistic)

---

## 🚀 Ready to Start!

This plan provides:
- ✅ Clear architecture and API design
- ✅ Detailed implementation steps
- ✅ Comprehensive test strategy
- ✅ Complete documentation structure
- ✅ Realistic timeline
- ✅ Success criteria
- ✅ Risk mitigation strategies

**Next Step**: Begin Phase 1 - Core Foundation (Day 1 Morning)

Good luck with the implementation! 🎉
