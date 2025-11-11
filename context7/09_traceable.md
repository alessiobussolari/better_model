# Traceable - Audit Trail e Versioning

## Panoramica

**Versione**: 3.0.0 | **Tipo**: Opt-in

Traceable fornisce un sistema completo di audit trail per tracciare tutte le modifiche ai record con informazioni su cosa è cambiato, quando, chi ha fatto il cambiamento e perché.

**Caratteristiche principali**:
- Tracking automatico di create/update/destroy
- Protezione dati sensibili (3 livelli di redazione)
- Time travel: ricostruire stato passato
- Rollback: ripristinare versioni precedenti
- User attribution e change context
- Query API per trovare record per cambiamenti
- Storage flessibile (per-model, shared, custom tables)
- Thread-safe

**Opt-in**: Traceable NON è attivo di default. Deve essere esplicitamente abilitato.

## Setup Database

### 1. Tabella Versions Base

**Cosa fa**: Crea la tabella per memorizzare le versioni dei record.

**Quando usarlo**: Prima di usare Traceable, serve una migration per creare la tabella versions.

**Esempio**:
```ruby
# migration
create_table :article_versions do |t|
  t.string :item_type, null: false
  t.bigint :item_id, null: false
  t.string :event
  t.jsonb :object_changes  # use jsonb per PostgreSQL
  t.bigint :updated_by_id
  t.string :updated_reason
  t.timestamps
end

add_index :article_versions, [:item_type, :item_id]
add_index :article_versions, :updated_by_id
add_index :article_versions, :created_at
add_index :article_versions, :object_changes, using: :gin  # PostgreSQL
```

### 2. Shared Table per Tutti i Models

**Cosa fa**: Crea una singola tabella condivisa per tracciare versioni di multipli models.

**Quando usarlo**: Quando vuoi centralizzare l'audit trail invece di creare una tabella per ogni model.

**Esempio**:
```ruby
# migration
create_table :better_model_versions do |t|
  t.string :item_type, null: false
  t.bigint :item_id, null: false
  t.string :event
  t.jsonb :object_changes
  t.bigint :updated_by_id
  t.string :updated_reason
  t.timestamps
end

add_index :better_model_versions, [:item_type, :item_id]
add_index :better_model_versions, :updated_by_id
add_index :better_model_versions, :created_at
```

## Configurazione Base

### 3. Abilitare Traceable

**Cosa fa**: Attiva il tracking delle modifiche su campi specifici del model.

**Quando usarlo**: Quando vuoi tracciare la storia delle modifiche ai dati del model.

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel

  traceable do
    track :status, :title, :content, :published_at
  end
end

# Uso
article = Article.create!(title: "Hello", status: "draft")
article.update!(status: "published")

article.versions.count  # => 2
article.versions.last.event  # => "updated"
article.versions.last.object_changes
# => {"status" => ["draft", "published"]}
```

### 4. Custom Table Name

**Cosa fa**: Specifica un nome custom per la tabella versions invece del default.

**Quando usarlo**: Quando vuoi usare naming convention specifiche o shared tables.

**Esempio**:
```ruby
class Article < ApplicationRecord
  traceable do
    versions_table :content_audit_trail  # custom name
    track :status, :title
  end
end

# O shared table
class BlogPost < ApplicationRecord
  traceable do
    versions_table :better_model_versions  # shared
    track :content, :published
  end
end
```

## Protezione Dati Sensibili

### 5. Redazione Completa (:full)

**Cosa fa**: Sostituisce completamente i valori con `[REDACTED]` nelle versioni.

**Quando usarlo**: Per password, chiavi di cifratura, secrets che non devono mai apparire nei log.

**Esempio**:
```ruby
class User < ApplicationRecord
  traceable do
    track :email, :name
    track :password_digest, sensitive: :full
    track :two_factor_secret, sensitive: :full
  end
end

user = User.create!(
  email: "user@example.com",
  password: "secret123"
)

version = user.versions.last
version.object_changes
# => {"password_digest" => ["[REDACTED]", "[REDACTED]"]}
```

### 6. Redazione Parziale (:partial)

**Cosa fa**: Maschera parzialmente i dati mostrando solo pattern riconoscibili.

**Quando usarlo**: Per credit card, SSN, email, phone dove serve vedere gli ultimi digit o pattern.

**Esempio**:
```ruby
class User < ApplicationRecord
  traceable do
    track :credit_card, sensitive: :partial
    track :ssn, sensitive: :partial
    track :email, sensitive: :partial
    track :phone, sensitive: :partial
  end
end

user.update!(
  credit_card: "4532123456789012",
  ssn: "123456789",
  email: "user@example.com",
  phone: "5551234567"
)

version.object_changes
# => {
#   "credit_card" => [nil, "****9012"],
#   "ssn" => [nil, "***-**-6789"],
#   "email" => [nil, "u***@example.com"],
#   "phone" => [nil, "***-***-4567"]
# }
```

### 7. Redazione Hash (:hash)

**Cosa fa**: Memorizza un hash SHA256 invece del valore reale.

**Quando usarlo**: Per API tokens, session IDs dove serve verificare se è cambiato senza vedere il valore.

**Esempio**:
```ruby
class User < ApplicationRecord
  traceable do
    track :api_token, sensitive: :hash
    track :session_id, sensitive: :hash
  end
end

user.update!(api_token: "secret_token_abc123")

version.object_changes
# => {"api_token" => [nil, "sha256:a1b2c3d4..."]}

# Puoi verificare se è cambiato confrontando gli hash
# ma non puoi recuperare il valore originale
```

## Metodi Instance - Visualizzazione

### 8. Visualizzare Tutte le Versioni

**Cosa fa**: Restituisce array di tutte le versioni del record (newest first).

**Quando usarlo**: Per mostrare la storia completa delle modifiche a un record.

**Esempio**:
```ruby
article = Article.find(1)
article.versions  # => [#<ArticleVersion>, ...]

article.versions.each do |v|
  puts "#{v.event} at #{v.created_at}"
  puts "By: #{v.updated_by_id}"
  puts "Reason: #{v.updated_reason}"
  puts "Changes: #{v.object_changes}"
end

# Accesso a versione specifica
latest = article.versions.first
latest.event          # => "updated"
latest.object_changes # => {"title" => ["Old", "New"]}
```

### 9. Storia di un Campo Specifico

**Cosa fa**: Mostra tutti i cambiamenti di un singolo campo nel tempo.

**Quando usarlo**: Quando ti interessa solo la storia di un campo specifico, non tutte le modifiche.

**Esempio**:
```ruby
article.changes_for(:status)
# => [
#   {
#     before: "draft",
#     after: "published",
#     at: 2025-01-15 14:30:00,
#     by: 123,
#     reason: "Ready for publication"
#   },
#   {
#     before: nil,
#     after: "draft",
#     at: 2025-01-15 10:00:00,
#     by: 123,
#     reason: "Initial draft"
#   }
# ]

# Check se campo è mai stato cambiato
article.changes_for(:featured).any?  # => true
```

### 10. Audit Trail Completo

**Cosa fa**: Restituisce array formattato con tutti gli eventi e cambiamenti.

**Quando usarlo**: Per mostrare una timeline completa delle modifiche in UI/API.

**Esempio**:
```ruby
article.audit_trail
# => [
#   {
#     event: "updated",
#     changes: {"status" => ["draft", "published"]},
#     at: 2025-01-15 14:30:00,
#     by: 123,
#     reason: "Ready for publication"
#   },
#   {
#     event: "created",
#     changes: {"title" => [nil, "Hello"]},
#     at: 2025-01-15 10:00:00,
#     by: 123,
#     reason: "Initial draft"
#   }
# ]

# Group by date per timeline view
timeline = article.audit_trail.group_by { |e| e[:at].to_date }
```

### 11. JSON con Audit Trail

**Cosa fa**: Includere audit trail nelle risposte JSON API.

**Quando usarlo**: Quando vuoi esporre la storia delle modifiche tramite API.

**Esempio**:
```ruby
article.as_json(include_audit_trail: true)
# => {
#   "id" => 1,
#   "title" => "Hello World",
#   "audit_trail" => [
#     {
#       "event" => "updated",
#       "changes" => {"status" => ["draft", "published"]},
#       "at" => "2025-01-15T14:30:00Z",
#       "by" => 123,
#       "reason" => "Ready for publication"
#     }
#   ]
# }
```

## Time Travel e Rollback

### 12. Time Travel - Ricostruire Stato Passato

**Cosa fa**: Ricostruisce lo stato dell'oggetto a un punto specifico nel tempo.

**Quando usarlo**: Per vedere come era un record in passato o confrontare con lo stato attuale.

**Esempio**:
```ruby
article = Article.find(1)

# Vedi articolo come era 3 giorni fa
past = article.as_of(3.days.ago)
past.title        # => "Old Title"
past.status       # => "draft"
past.readonly?    # => true (non salvabile)

# A timestamp specifico
past = article.as_of(Time.new(2025, 1, 10, 14, 30))

# Confronto passato-presente
puts "Title: #{past.title} → #{article.title}"
puts "Status: #{past.status} → #{article.status}"
```

### 13. Rollback a Versione Precedente

**Cosa fa**: Ripristina il record a una versione precedente creando una nuova versione.

**Quando usarlo**: Per annullare modifiche errate o ripristinare uno stato precedente valido.

**Esempio**:
```ruby
# Trova versione da ripristinare
version = article.versions.find_by(event: "published")

# Rollback
article.rollback_to(
  version,
  updated_by_id: current_user.id,
  updated_reason: "Reverted accidental change"
)

# O per ID
article.rollback_to(
  42,  # version ID
  updated_by_id: current_user.id,
  updated_reason: "Restored previous state"
)
```

### 14. Rollback con Validazioni

**Cosa fa**: Rollback con validazioni abilitate (skippate di default).

**Quando usarlo**: Quando vuoi assicurarti che il rollback produca un record valido.

**Esempio**:
```ruby
article.rollback_to(
  version,
  updated_by_id: current_user.id,
  updated_reason: "Rollback with validation",
  validate: true  # Run validations
)

# Se le validazioni falliscono, il rollback non viene eseguito
if article.rollback_to(version, validate: true, updated_by_id: user.id)
  puts "Rollback successful"
else
  puts "Rollback failed: #{article.errors.full_messages}"
end
```

### 15. Rollback e Campi Sensitivi

**Cosa fa**: Controlla se i campi sensitivi vengono inclusi nel rollback.

**Quando usarlo**: Quando serve decidere se ripristinare anche dati sensitivi (generalmente sconsigliato).

**Esempio**:
```ruby
user = User.create!(
  email: "user@example.com",
  password_digest: "secret123"  # sensitive: :full
)

user.update!(email: "new@example.com", password_digest: "new")

# Default: campi sensitivi NON rolled back
user.rollback_to(user.versions.first, updated_by_id: admin.id)
user.email           # => "user@example.com" (ripristinato)
user.password_digest # => "new" (NON ripristinato)

# Con allow_sensitive: imposta valore redatto
user.rollback_to(user.versions.first,
  updated_by_id: admin.id,
  allow_sensitive: true
)
user.password_digest # => "[REDACTED]" (dal valore storato)
```

## Query e Class Methods

### 16. Query per User - changed_by

**Cosa fa**: Trova tutti i record modificati da un utente specifico.

**Quando usarlo**: Per audit report, tracking attività utente, monitoring modifiche admin.

**Esempio**:
```ruby
# Articoli modificati da user 123
Article.changed_by(123)

# Con filtri addizionali
Article.changed_by(current_user.id)
       .where(status: "published")

# Count modifiche per user
Article.changed_by(current_user.id).count

# Multipli users
admin_ids = User.where(role: "admin").pluck(:id)
Article.changed_by(admin_ids)
```

### 17. Query per Range Temporale - changed_between

**Cosa fa**: Trova record modificati in un intervallo di tempo specifico.

**Quando usarlo**: Per report periodici, incident analysis, compliance audits.

**Esempio**:
```ruby
# Modifiche questa settimana
Article.changed_between(1.week.ago, Time.current)

# Modifiche in Gennaio 2025
Article.changed_between(
  Time.new(2025, 1, 1),
  Time.new(2025, 1, 31).end_of_day
)

# Combina con user filter
Article.changed_by(current_user.id)
       .changed_between(1.month.ago, Time.current)

# Oggi
Article.changed_between(
  Time.current.beginning_of_day,
  Time.current
)
```

### 18. Query per Campo Cambiato

**Cosa fa**: Trova record dove un campo specifico è stato modificato.

**Quando usarlo**: Per tracking modifiche a campi specifici (es: prezzo, status, permessi).

**Esempio**:
```ruby
# Tutti gli articoli dove title è cambiato
Article.field_changed(:title)

# Articoli dove status è cambiato a "published"
Article.field_changed(:status)
       .where("object_changes->>'status' LIKE '%published%'")

# Con altri filtri
Article.field_changed(:price)
       .changed_between(1.week.ago, Time.current)
```

### 19. Query Transition Specifica

**Cosa fa**: Trova record con transizioni specifiche di valore per un campo.

**Quando usarlo**: Per tracking workflow specifici (draft→published, pending→approved, etc).

**Esempio**:
```ruby
class Article < ApplicationRecord
  traceable do
    track :status, :title, :priority
  end
end

# Genera automaticamente:
Article.status_changed_from("draft").to("published")
Article.title_changed_from(nil).to("Hello World")
Article.priority_changed_from(1).to(5)

# Uso pratico
published_articles = Article.status_changed_from("draft")
                            .to("published")

# Combina con altri scopes
Article.status_changed_from("draft").to("published")
       .changed_by(current_user.id)
       .changed_between(1.week.ago, Time.current)
```

### 20. Combinare Query Multiple

**Cosa fa**: Combina filtri multipli per query complesse di audit.

**Quando usarlo**: Per report dettagliati, compliance audits, incident analysis.

**Esempio**:
```ruby
# Report complesso
Article.changed_by(admin.id)
       .changed_between(1.month.ago, Time.current)
       .status_changed_from("draft").to("published")
       .includes(:versions)

# Post-incident analysis
incident_time = (incident.started_at)..(incident.ended_at)
suspicious_changes = Article
  .changed_between(incident_time.begin, incident_time.end)
  .field_changed(:price)
  .where("(object_changes->>'price')::jsonb->1 > ?", 1000)
```

## User Attribution

### 21. Impostare updated_by_id Automaticamente

**Cosa fa**: Imposta automaticamente chi ha fatto la modifica tramite callback.

**Quando usarlo**: Per evitare di passare sempre manualmente updated_by_id.

**Esempio**:
```ruby
class Article < ApplicationRecord
  traceable do
    track :status, :title, :content
  end

  before_save :set_updated_by

  private

  def set_updated_by
    self.updated_by_id = Current.user&.id if Current.user
  end
end

# Setup Current.user (application_controller.rb)
class ApplicationController < ActionController::Base
  before_action :set_current_user

  private

  def set_current_user
    Current.user = current_user
  end
end

# Ora tutti gli update trackano automaticamente
article.update!(status: "published")
# Crea version con updated_by_id = Current.user.id
```

### 22. Passare updated_reason Esplicitamente

**Cosa fa**: Specifica il motivo della modifica per audit trail migliore.

**Quando usarlo**: Sempre, specialmente per compliance e regulatory requirements.

**Esempio**:
```ruby
# In controller
article.update!(
  status: "published",
  updated_by_id: current_user.id,
  updated_reason: "Approved after editorial review"
)

# Con form input
def article_params_with_metadata
  params.require(:article)
        .permit(:title, :content, :status)
        .merge(
          updated_by_id: current_user.id,
          updated_reason: params[:change_reason] || "Article updated"
        )
end

# Service object
class OrderProcessor
  def ship_order(order, tracking:, user:)
    order.update!(
      status: "shipped",
      tracking_number: tracking,
      updated_by_id: user.id,
      updated_reason: "Order shipped with tracking #{tracking}"
    )
  end
end
```

### 23. Validazione Obbligatoria User e Reason

**Cosa fa**: Forza la presenza di updated_by_id e updated_reason per compliance.

**Quando usarlo**: In contesti regulated (healthcare, finance) dove l'audit trail è obbligatorio.

**Esempio**:
```ruby
class MedicalRecord < ApplicationRecord
  traceable do
    track :diagnosis, :treatment_plan, :medications
  end

  # Compliance: obbligatorio per update
  validates :updated_by_id, presence: true, on: :update
  validates :updated_reason, presence: true, on: :update
end

# In controller
def update
  unless params[:update_reason].present?
    return render json: {
      error: "Update reason required for compliance"
    }, status: :unprocessable_entity
  end

  @record.update!(
    medical_record_params.merge(
      updated_by_id: current_user.id,
      updated_reason: params[:update_reason]
    )
  )
end
```

## Casi d'Uso Real-World

### 24. CMS - Article Versioning

**Cosa fa**: Sistema completo di versioning per CMS con rollback e audit log.

**Quando usarlo**: Content management systems che richiedono storia editoriale completa.

**Esempio**:
```ruby
class Article < ApplicationRecord
  traceable do
    track :title, :content, :status, :published_at, :excerpt
  end

  before_save :set_updated_by
  def set_updated_by
    self.updated_by_id = Current.user&.id if Current.user
  end
end

# Controller
class ArticlesController < ApplicationController
  def update
    if @article.update(article_params.merge(
      updated_by_id: current_user.id,
      updated_reason: params[:change_reason]
    ))
      redirect_to @article, notice: "Article updated"
    end
  end

  def revert
    version = @article.versions.find(params[:version_id])
    @article.rollback_to(version, updated_by_id: current_user.id)
    redirect_to @article, notice: "Reverted"
  end
end
```

### 25. E-commerce - Order Tracking

**Cosa fa**: Traccia tutte le modifiche agli ordini con audit trail per admin.

**Quando usarlo**: E-commerce dove serve tracciare status, shipping, modifiche admin.

**Esempio**:
```ruby
class Order < ApplicationRecord
  traceable do
    versions_table :order_audit_trail
    track :status, :shipping_address, :total_amount
  end

  # Scope personalizzati
  def self.shipped_today
    changed_between(Time.current.beginning_of_day, Time.current)
      .status_changed_from("processing").to("shipped")
  end

  def self.admin_modifications
    admin_ids = User.where(role: "admin").pluck(:id)
    changed_by(admin_ids)
  end
end

# Service
class OrderProcessor
  def ship_order(order, tracking:, user:)
    order.update!(
      status: "shipped",
      tracking_number: tracking,
      updated_by_id: user.id,
      updated_reason: "Shipped: #{tracking}"
    )
  end
end
```

### 26. Document Approval Workflow

**Cosa fa**: Traccia approval/rejection di documenti con storia completa.

**Quando usarlo**: Workflow di approvazione con multiple revisioni e autorizzazioni.

**Esempio**:
```ruby
class Document < ApplicationRecord
  traceable do
    track :status, :approved_at, :rejected_at, :approval_notes
  end

  validates :updated_by_id, presence: true, on: :update
  validates :updated_reason, presence: true, on: :update

  def approve!(by:, notes: nil)
    update!(
      status: "approved",
      approved_at: Time.current,
      updated_by_id: by.id,
      updated_reason: notes || "Document approved"
    )
  end

  def approval_history
    changes_for(:status).select do |change|
      ["approved", "rejected"].include?(change[:after])
    end
  end
end
```

### 27. Healthcare/Finance Compliance

**Cosa fa**: Audit trail obbligatorio per settori regolamentati (HIPAA, SOX).

**Quando usarlo**: Healthcare, finance, ogni contesto regulated con compliance requirements.

**Esempio**:
```ruby
class MedicalRecord < ApplicationRecord
  traceable do
    versions_table :medical_audit_trail
    track :diagnosis, :treatment_plan, :medications
  end

  validates :updated_by_id, presence: true, on: :update
  validates :updated_reason, presence: true, on: :update

  # Export per compliance
  def compliance_report
    {
      record_id: id,
      patient_id: patient_id,
      changes: versions.map do |v|
        {
          timestamp: v.created_at.iso8601,
          user_id: v.updated_by_id,
          user_name: User.find(v.updated_by_id).full_name,
          event: v.event,
          reason: v.updated_reason,
          changes: v.object_changes
        }
      end
    }
  end
end
```

### 28. User Account con Dati Sensibili

**Cosa fa**: Traccia modifiche a user account proteggendo dati sensibili.

**Quando usarlo**: User management con password, SSN, dati di pagamento da proteggere.

**Esempio**:
```ruby
class User < ApplicationRecord
  traceable do
    track :email, :name, :role, :status
    track :password_digest, sensitive: :full
    track :ssn, sensitive: :partial
    track :api_token, sensitive: :hash
  end

  # Security audit
  def security_change_log
    changes_for(:password_digest)
      .concat(changes_for(:two_factor_secret))
      .sort_by { |c| c[:at] }.reverse
  end

  def password_changed_recently?(days = 90)
    changes_for(:password_digest)
      .any? { |c| c[:at] > days.days.ago }
  end
end

# Service
class UserManagementService
  def change_role(user, new_role:, by:, reason:)
    user.update!(
      role: new_role,
      updated_by_id: by.id,
      updated_reason: "Role changed: #{reason}"
    )
  end
end
```

### 29. Multi-Tenant Config Management

**Cosa fa**: Traccia modifiche a configurazioni tenant con rollback.

**Quando usarlo**: SaaS multi-tenant dove config changes devono essere tracciati e reversibili.

**Esempio**:
```ruby
class TenantConfig < ApplicationRecord
  traceable do
    versions_table :config_audit_trail
    track :api_enabled, :webhook_url, :rate_limit, :features
  end

  def self.admin_changes_for_tenant(tenant_id)
    admin_ids = User.where(tenant_id: tenant_id,
                          role: "admin").pluck(:id)
    where(tenant_id: tenant_id).changed_by(admin_ids)
  end
end

# Rollback service
class ConfigRollbackService
  def rollback_to_previous(config)
    prev = config.versions.where(event: "updated").second
    return false unless prev

    config.rollback_to(prev,
      updated_by_id: Current.user.id,
      updated_reason: "Rolled back due to issues"
    )
  end
end
```

### 30. Feature Flag Management

**Cosa fa**: Traccia toggle di feature flags per debugging e rollback.

**Quando usarlo**: Feature flag system dove serve sapere quando/chi ha toggleato flag.

**Esempio**:
```ruby
class FeatureFlag < ApplicationRecord
  traceable do
    track :enabled, :rollout_percentage, :enabled_for_users
  end

  # Flags toggleati durante incident
  def self.toggled_during(time_range)
    field_changed(:enabled)
      .changed_between(time_range.begin, time_range.end)
  end

  def enabled_at?(timestamp)
    as_of(timestamp).enabled
  end
end

# Service
class FeatureFlagService
  def emergency_rollback(flag, by:, incident_id:)
    incident = Incident.find(incident_id)
    safe = flag.versions
               .where("created_at < ?", incident.started_at)
               .last

    flag.rollback_to(safe,
      updated_by_id: by.id,
      updated_reason: "Emergency rollback: incident #{incident_id}"
    )
  end
end
```

## Performance e Best Practices

### 31. Indici Corretti

**Cosa fa**: Indici essenziali per query performanti su tabelle versions.

**Quando usarlo**: Sempre, nella migration che crea la tabella versions.

**Esempio**:
```ruby
# Essential indexes (required)
add_index :versions, [:item_type, :item_id]
add_index :versions, :created_at
add_index :versions, :updated_by_id

# PostgreSQL: JSONB indexes
add_index :versions, :object_changes, using: :gin

# Composite per query comuni
add_index :versions, [:item_type, :item_id, :created_at]
add_index :versions, [:updated_by_id, :created_at]

# Query optimization
@articles = Article.includes(:versions).limit(10)
article.versions.limit(10).order(created_at: :desc)
```

### 32. Archiviazione Versioni Vecchie

**Cosa fa**: Archivia o elimina versioni vecchie per gestire crescita tabella.

**Quando usarlo**: Retention policy per evitare crescita infinita della tabella versions.

**Esempio**:
```ruby
# Job periodico
class ArchiveOldVersionsJob < ApplicationJob
  def perform
    cutoff = 2.years.ago

    ArticleVersion.where("created_at < ?", cutoff)
                  .find_in_batches(batch_size: 1000) do |batch|
      # Archivia su S3/storage esterno
      archive_to_s3(batch)
      # Poi elimina
      batch.each(&:destroy)
    end
  end
end

# Cleanup versioni vuote
class CleanupEmptyVersionsJob < ApplicationJob
  def perform
    Version.where("created_at < ?", 1.year.ago)
           .where(event: "updated")
           .where("object_changes = '{}'::jsonb")
           .delete_all
  end
end
```

### 33. Query JSON Ottimizzate (PostgreSQL)

**Cosa fa**: Sfrutta operatori JSONB di PostgreSQL per query efficienti.

**Quando usarlo**: PostgreSQL con colonna jsonb per query su campi specifici nelle versions.

**Esempio**:
```ruby
# Query su valori specifici in object_changes
Article.joins(:versions)
       .where("object_changes->>'status' = ?", "published")

# Query con casting per numeri
Product.joins(:versions)
       .where("(object_changes->>'price')::numeric > ?", 100)

# Array contains (PostgreSQL)
Article.joins(:versions)
       .where("object_changes @> ?",
              { status: ["draft", "published"] }.to_json)

# Existance check
Article.joins(:versions)
       .where("object_changes ? :key", key: "status")
```

### 34. Introspection Configuration

**Cosa fa**: Verifica configurazione Traceable a runtime.

**Quando usarlo**: Per debug, testing, o UI che mostra campi tracciati.

**Esempio**:
```ruby
User.traceable_enabled?
# => true

User.traceable_sensitive_fields
# => {
#   password_digest: :full,
#   ssn: :partial,
#   api_token: :hash
# }

User.traceable_config
# => {
#   tracked_fields: [:email, :name, :password_digest, :ssn],
#   sensitive_fields: {...},
#   versions_table: :user_versions
# }
```

## Best Practices

### ✅ Do

1. **Track solo campi meaningful**: Track dati business-critical, non computed fields o cache
2. **User attribution sempre**: Sempre track updated_by_id e updated_reason
3. **Proteggi dati sensibili**: Usa `:full`, `:partial`, `:hash` appropriatamente
4. **Indici corretti**: Sempre add required indexes alla tabella versions
5. **Retention policy**: Implementa archiviazione/cleanup di versioni vecchie
6. **Test time travel**: Test che as_of ricostruisca stato correttamente
7. **Transactions per rollback**: Wrap rollback in transaction con altre update
8. **Documenta tracked fields**: Documenta quali campi sono tracciati e perché

### ❌ Don't

1. **Non trackare senza protezione**: Mai track password/secrets senza `sensitive:`
2. **Non trackare computed fields**: Non tracciare campi derivati da altri
3. **Non versionare binary data**: Non tracciare blob, track solo reference IDs
4. **Non ignorare performance**: N+1 queries, eager load versions quando serve
5. **Non skip indexes**: Causa slow queries su tabelle grandi
6. **Non dimenticare retention**: Tabella cresce infinitamente senza cleanup
7. **Non mix table strategies**: Scegli one strategy (per-model/shared) project-wide
8. **Non rollback sensitive fields**: Di default sono skipped, usa `allow_sensitive` con cautela

## Errori Comuni

### Errore: Schema Columns Mancanti

```ruby
# ❌ Errore se mancano colonne nella tabella
class Article < ApplicationRecord
  traceable do
    track :status
  end
end

# Fallisce se la tabella versions non ha:
# - item_type (required)
# - item_id (required)
# - object_changes (required)
# - event (required)

# ✅ Verifica schema
rails db:migrate:status
# Assicurati migration versions table sia eseguita
```

### Errore: Rollback a Versione di Altro Record

```ruby
# ❌ Rollback con versione di altro record
article1 = Article.find(1)
article2 = Article.find(2)

article1.rollback_to(article2.versions.first)
# Errore: version non appartiene a article1

# ✅ Usa solo versioni del record stesso
article1.rollback_to(article1.versions.first,
  updated_by_id: user.id
)
```

## Integrazione con Altri Features

### Con Archivable

```ruby
class Article < ApplicationRecord
  include BetterModel

  archivable
  traceable do
    track :status, :title, :archived_at, :archived_by_id
  end
end

# Archive tracked nella history
article.archive!(by: user, reason: "Outdated")
article.changes_for(:archived_at)
# => [{before: nil, after: 2025-01-15, by: 123}]
```

### Con Stateable

```ruby
class Order < ApplicationRecord
  include BetterModel

  stateable do
    state :pending, initial: true
    state :shipped
    event :ship do
      transition from: :pending, to: :shipped
    end
  end

  traceable do
    track :state, :shipped_at
  end
end

# State transitions tracked
order.ship!
order.changes_for(:state)
# => [{before: "pending", after: "shipped"}]
```

### Con Statusable

```ruby
class Article < ApplicationRecord
  include BetterModel

  statusable do
    status :featured, -> { published_at.present? }
  end

  traceable do
    track :published_at  # Tracked, featured? è computed
  end
end

# Track field che influenza status, non status stesso
```

## Key Takeaways

1. **Opt-In**: Traceable NON è attivo di default, deve essere abilitato esplicitamente
2. **Explicit Tracking**: Solo campi specificati sono tracciati, gli altri no
3. **Correct Schema**: Usa `item_type`/`item_id`, `updated_by_id`, `object_changes`
4. **Sensitive Protection**: 3 livelli - `:full`, `:partial`, `:hash`
5. **User Attribution**: Sempre track chi e perché con updated_by_id/reason
6. **Time Travel**: `as_of(timestamp)` ricostruisce stato passato (readonly)
7. **Rollback Safety**: Campi sensitivi skipped di default
8. **Rich Query API**: `changed_by`, `changed_between`, `field_changed_from().to()`
9. **Table Strategies**: Per-model, shared, o custom tables
10. **Database Optimization**: JSONB per PostgreSQL, GIN indexes, plan for growth
11. **Compliance Ready**: HIPAA, GDPR, SOX con mandatory user/reason
12. **Performance**: Index properly, eager load, retention policies
13. **Thread Safe**: Immutable config, safe per concurrent requests
14. **Integration**: Funziona con Archivable, Stateable, Statusable
15. **Testing**: Test time travel e rollback functionality

---

**Compatibile con**: Rails 8.0+, Ruby 3.0+, PostgreSQL (recommended), MySQL, SQLite
**Thread-safe**: Sì
**Opt-in**: Sì (richiede `traceable do...end`)
