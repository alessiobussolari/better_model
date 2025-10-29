# BetterModel - Roadmap Implementativa

Questo documento suddivide l'implementazione di BetterModel in **37 step incrementali** organizzati in **9 milestone**.

**Progress Tracking:** 0/37 step completati (0%)

---

## MILESTONE 1: Setup Base (Step 1-3)

### Step 1: Setup Gem Structure

**Milestone:** 1
**Dipende da:** -
**Tempo stimato:** 1-2 ore
**Status:** ⬜ Todo

#### Obiettivo
Creare la struttura base del gem con Gemfile, gemspec, e file principale.

#### File da creare
- `better_model.gemspec`
- `Gemfile`
- `lib/better_model.rb`
- `lib/better_model/version.rb`
- `README.md`
- `MIT-LICENSE`
- `.gitignore`
- `.rubocop.yml`

#### Checklist implementazione
- [ ] Creare `better_model.gemspec` con dependencies (Rails 8.1+)
- [ ] Creare `Gemfile` con development dependencies
- [ ] Creare `lib/better_model.rb` con autoload dei concern
- [ ] Creare `lib/better_model/version.rb` (VERSION = "0.1.0")
- [ ] Creare README.md base con descrizione
- [ ] Configurare RuboCop con regole Rails

#### Criterio di successo
```bash
bundle install  # Esegue senza errori
ruby -Ilib -rbetter_model -e "puts BetterModel::VERSION"  # => 0.1.0
```

#### Riferimento
Implementation plan: linee 1-150

---

### Step 2: Setup Test Environment

**Milestone:** 1
**Dipende da:** Step 1
**Tempo stimato:** 2-3 ore
**Status:** ⬜ Todo

#### Obiettivo
Configurare ambiente di test con dummy Rails app e test_helper.

#### File da creare
- `test/test_helper.rb`
- `test/dummy/config/application.rb`
- `test/dummy/config/environment.rb`
- `test/dummy/config/database.yml`
- `test/dummy/db/schema.rb`
- `Rakefile`

#### Checklist implementazione
- [ ] Creare dummy Rails app in `test/dummy/`
- [ ] Configurare `test_helper.rb` per Rails test
- [ ] Creare database schema per test (articles table)
- [ ] Configurare fixtures
- [ ] Creare `Rakefile` con task test

#### Criterio di successo
```bash
rake db:test:prepare  # Crea test database
rake test  # Esegue senza errori (0 test per ora)
```

#### Riferimento
Implementation plan: linee 2400-2450

---

### Step 3: Setup CI/GitHub Actions

**Milestone:** 1
**Dipende da:** Step 2
**Tempo stimato:** 1 ora
**Status:** ⬜ Todo

#### Obiettivo
Configurare GitHub Actions per CI con multiple Ruby versions e database.

#### File da creare
- `.github/workflows/ci.yml`
- `.github/workflows/rubocop.yml`

#### Checklist implementazione
- [ ] Creare workflow CI per test (Ruby 3.2, 3.3)
- [ ] Configurare matrix per database (SQLite, PostgreSQL, MySQL)
- [ ] Creare workflow RuboCop
- [ ] Aggiungere badge nel README

#### Criterio di successo
```bash
# Push su GitHub → Actions runs → ✅ All green
```

#### Riferimento
Best practices Rails gem CI

---

## MILESTONE 2: Attributes (Step 4-8)

### Step 4: Type Registry + Validazione Base

**Milestone:** 2
**Dipende da:** Step 2
**Tempo stimato:** 2 ore
**Status:** ⬜ Todo

#### Obiettivo
Creare registry dei tipi supportati e validazione base per typed_attribute.

#### File da creare
- `lib/better_model/attributes.rb`
- `test/better_model/attributes_test.rb`

#### Checklist implementazione
- [ ] Creare modulo `BetterModel::Attributes`
- [ ] Implementare `TYPES_REGISTRY` con tipi: `:string`, `:integer`, `:boolean`
- [ ] Implementare `typed_attribute(name, type, **options)`
- [ ] Validare che tipo sia nel registry
- [ ] Test: attributo string, integer, boolean

#### Criterio di successo
```ruby
class Article < ApplicationRecord
  include BetterModel::Attributes
  typed_attribute :title, :string
  typed_attribute :view_count, :integer
  typed_attribute :published, :boolean
end

article = Article.new(title: "Test", view_count: 100, published: true)
article.valid?  # => true
```

#### Riferimento
Implementation plan: linee 200-280

---

### Step 5: Typed Attributes (String, Integer, Boolean)

**Milestone:** 2
**Dipende da:** Step 4
**Tempo stimato:** 2 ore
**Status:** ⬜ Todo

#### Obiettivo
Implementare validazioni specifiche per string, integer e boolean types.

#### File da modificare
- `lib/better_model/attributes.rb`
- `test/better_model/attributes_test.rb`

#### Checklist implementazione
- [ ] String: validazione `allow_blank`, `default`
- [ ] Integer: validazione `greater_than`, `less_than`
- [ ] Boolean: toggle method `toggle_#{attribute}!`
- [ ] Test: validazioni per ogni tipo
- [ ] Test: toggle method per boolean

#### Criterio di successo
```ruby
typed_attribute :active, :boolean
article.active = true
article.toggle_active!
article.active  # => false
```

#### Riferimento
Implementation plan: linee 200-350

---

### Step 6: Email & URL Attributes

**Milestone:** 2
**Dipende da:** Step 5
**Tempo stimato:** 2 ore
**Status:** ⬜ Todo

#### Obiettivo
Implementare tipi `:email` e `:url` con validazione formato.

#### File da modificare
- `lib/better_model/attributes.rb`
- `test/better_model/attributes_test.rb`

#### Checklist implementazione
- [ ] Aggiungere `:email` a TYPES_REGISTRY
- [ ] Aggiungere `:url` a TYPES_REGISTRY
- [ ] Email: regex validation `URI::MailTo::EMAIL_REGEXP`
- [ ] URL: regex validation `URI::DEFAULT_PARSER.make_regexp`
- [ ] Helper method `email_attribute(name, **options)`
- [ ] Test: email valide/invalide
- [ ] Test: URL valide/invalide

#### Criterio di successo
```ruby
email_attribute :author_email
article = Article.new(author_email: "invalid")
article.valid?  # => false
article.errors[:author_email]  # => ["is not a valid email"]
```

#### Riferimento
Implementation plan: linee 320-380

---

### Step 7: Array Attributes + Helper Methods

**Milestone:** 2
**Dipende da:** Step 6
**Tempo stimato:** 2 ore
**Status:** ⬜ Todo

#### Obiettivo
Implementare tipo `:array` con metodi `add_to_*` e `remove_from_*`.

#### File da modificare
- `lib/better_model/attributes.rb`
- `test/better_model/attributes_test.rb`

#### Checklist implementazione
- [ ] Aggiungere `:array` a TYPES_REGISTRY
- [ ] Serialize array (PostgreSQL array o JSON)
- [ ] Metodo `add_to_#{attribute}(value)`
- [ ] Metodo `remove_from_#{attribute}(value)`
- [ ] Test: add/remove su array
- [ ] Test: array vuoto vs nil

#### Criterio di successo
```ruby
typed_attribute :tags, :array, default: []
article.add_to_tags("rails")
article.tags  # => ["rails"]
article.remove_from_tags("rails")
article.tags  # => []
```

#### Riferimento
Implementation plan: linee 280-320

---

### Step 8: JSON Attributes con Schema Validation

**Milestone:** 2
**Dipende da:** Step 7
**Tempo stimato:** 3 ore
**Status:** ⬜ Todo

#### Obiettivo
Implementare tipo `:better_json` con validazione schema opzionale.

#### File da modificare
- `lib/better_model/attributes.rb`
- `test/better_model/attributes_test.rb`

#### Checklist implementazione
- [ ] Aggiungere `:better_json` a TYPES_REGISTRY
- [ ] Serialize come JSON (attribute :metadata, :json)
- [ ] Validazione schema opzionale con `schema:` option
- [ ] Helper `json_attribute(name, schema: {...})`
- [ ] Test: JSON valido/invalido
- [ ] Test: schema validation

#### Criterio di successo
```ruby
json_attribute :metadata, schema: {
  type: :object,
  required: [:author],
  properties: { author: { type: :string } }
}

article.metadata = { author: "John" }
article.valid?  # => true

article.metadata = { foo: "bar" }
article.valid?  # => false (missing :author)
```

#### Riferimento
Implementation plan: linee 350-420

---

## MILESTONE 3: Validations (Step 9-12)

### Step 9: Validation DSL Base

**Milestone:** 3
**Dipende da:** Step 2
**Tempo stimato:** 2 ore
**Status:** ⬜ Todo

#### Obiettivo
Creare DSL per validazioni espressive (`required`, `validate_all`).

#### File da creare
- `lib/better_model/validations.rb`
- `test/better_model/validations_test.rb`

#### Checklist implementazione
- [ ] Creare modulo `BetterModel::Validations`
- [ ] Implementare `required(*fields, **options)`
- [ ] Implementare `validate_all(*fields, **validations)`
- [ ] Test: required su singolo campo
- [ ] Test: required su multipli campi
- [ ] Test: validate_all con length, format

#### Criterio di successo
```ruby
class Article < ApplicationRecord
  include BetterModel::Validations
  required :title, :content
  validate_all :title, :subtitle, length: { minimum: 3 }
end

article = Article.new
article.valid?  # => false
article.errors[:title]  # => ["can't be blank", "is too short"]
```

#### Riferimento
Implementation plan: linee 450-550

---

### Step 10: Email & URL Validators

**Milestone:** 3
**Dipende da:** Step 9
**Tempo stimato:** 1 ora
**Status:** ⬜ Todo

#### Obiettivo
Creare validator custom per email e URL.

#### File da modificare
- `lib/better_model/validations.rb`
- `test/better_model/validations_test.rb`

#### Checklist implementazione
- [ ] Creare `EmailValidator < ActiveModel::EachValidator`
- [ ] Creare `UrlValidator < ActiveModel::EachValidator`
- [ ] Implementare `validates_email(*fields, **options)`
- [ ] Implementare `validates_url(*fields, **options)`
- [ ] Test: email validator
- [ ] Test: URL validator
- [ ] Test: allow_blank option

#### Criterio di successo
```ruby
validates_email :email, :backup_email
validates_url :website, allow_blank: true

article = Article.new(email: "invalid")
article.valid?  # => false
article.errors[:email]  # => ["is not a valid email"]
```

#### Riferimento
Implementation plan: linee 550-610

---

### Step 11: Context-Based Validations

**Milestone:** 3
**Dipende da:** Step 10
**Tempo stimato:** 2 ore
**Status:** ⬜ Todo

#### Obiettivo
Implementare `validates_on` per validazioni contestuali.

#### File da modificare
- `lib/better_model/validations.rb`
- `test/better_model/validations_test.rb`

#### Checklist implementazione
- [ ] Implementare `validates_on(context, &block)`
- [ ] DSL block esegue validazioni nel contesto
- [ ] Test: validazioni solo su contesto specifico
- [ ] Test: `valid?(:publication)` vs `valid?`

#### Criterio di successo
```ruby
validates_on :publication do
  required :subtitle, :summary
  validates :content, length: { minimum: 100 }
end

article = Article.new(title: "Test")
article.valid?  # => true (no subtitle required)
article.valid?(:publication)  # => false (subtitle required)
```

#### Riferimento
Implementation plan: linee 610-680

---

### Step 12: Conditional Validations

**Milestone:** 3
**Dipende da:** Step 11
**Tempo stimato:** 1 ora
**Status:** ⬜ Todo

#### Obiettivo
Aggiungere supporto per `:if` e `:unless` nelle validazioni.

#### File da modificare
- `lib/better_model/validations.rb`
- `test/better_model/validations_test.rb`

#### Checklist implementazione
- [ ] Passare `:if` e `:unless` a `validates`
- [ ] Test: validazione condizionale con lambda
- [ ] Test: validazione condizionale con method name

#### Criterio di successo
```ruby
required :subtitle, if: :published?
validates :summary, presence: true, unless: -> { draft? }

article = Article.new(status: "draft")
article.valid?  # => true (subtitle not required for draft)
```

#### Riferimento
Implementation plan: linee 680-750

---

## MILESTONE 4: StateMachine (Step 13-18)

### Step 13: State Definition + Initial State

**Milestone:** 4
**Dipende da:** Step 2
**Tempo stimato:** 3 ore
**Status:** ⬜ Todo

#### Obiettivo
Creare DSL per definire stati e stato iniziale della state machine.

#### File da creare
- `lib/better_model/state_machine.rb`
- `lib/better_model/state_machine/machine_builder.rb`
- `test/better_model/state_machine_test.rb`

#### Checklist implementazione
- [ ] Creare modulo `BetterModel::StateMachine`
- [ ] Creare classe `MachineBuilder` con DSL
- [ ] Implementare `state_machine(column, &block)`
- [ ] Implementare `states(*state_names)` nel DSL
- [ ] Implementare `initial(state_name)` nel DSL
- [ ] Test: definizione stati
- [ ] Test: initial state su after_initialize

#### Criterio di successo
```ruby
class Article < ApplicationRecord
  include BetterModel::StateMachine

  state_machine :status do
    initial :draft
    states :draft, :in_review, :published
  end
end

article = Article.new
article.status  # => :draft
```

#### Riferimento
Implementation plan: linee 750-850

---

### Step 14: Transition Definition

**Milestone:** 4
**Dipende da:** Step 13
**Tempo stimato:** 3 ore
**Status:** ⬜ Todo

#### Obiettivo
Implementare definizione transizioni con `from` e `to`.

#### File da modificare
- `lib/better_model/state_machine/machine_builder.rb`
- `lib/better_model/state_machine/transition.rb` (nuovo)
- `test/better_model/state_machine_test.rb`

#### Checklist implementazione
- [ ] Creare classe `Transition` con `from`, `to`, `name`
- [ ] Implementare `transition(name, from:, to:)` nel DSL
- [ ] Validare stati from/to esistano
- [ ] Test: definizione transizione
- [ ] Test: transizione tra stati validi

#### Criterio di successo
```ruby
state_machine :status do
  initial :draft
  states :draft, :in_review, :published

  transition :publish, from: [:draft, :in_review], to: :published
end

article.status = :draft
# Preparazione per metodi in step successivi
```

#### Riferimento
Implementation plan: linee 850-920

---

### Step 15: Conditions (if/unless)

**Milestone:** 4
**Dipende da:** Step 14
**Tempo stimato:** 2 ore
**Status:** ⬜ Todo

#### Obiettivo
Aggiungere condizioni `if` e `unless` alle transizioni.

#### File da modificare
- `lib/better_model/state_machine/transition.rb`
- `test/better_model/state_machine_test.rb`

#### Checklist implementazione
- [ ] Aggiungere `:if` e `:unless` a `Transition`
- [ ] Implementare `can_execute?(record, column)`
- [ ] Supportare lambda, symbol, proc
- [ ] Test: transizione con condizione if
- [ ] Test: transizione bloccata da unless

#### Criterio di successo
```ruby
transition :publish,
  from: [:draft, :in_review],
  to: :published,
  if: :valid_for_publication?

def valid_for_publication?
  title.present? && content.present?
end

article.status = :draft
article.can_publish?  # Da implementare in step 17
```

#### Riferimento
Implementation plan: linee 850-920

---

### Step 16: Callbacks (before/after)

**Milestone:** 4
**Dipende da:** Step 15
**Tempo stimato:** 2 ore
**Status:** ⬜ Todo

#### Obiettivo
Implementare callback `before` e `after` per transizioni.

#### File da modificare
- `lib/better_model/state_machine/transition.rb`
- `test/better_model/state_machine_test.rb`

#### Checklist implementazione
- [ ] Aggiungere `:before` e `:after` a `Transition`
- [ ] Eseguire callback prima/dopo cambio stato
- [ ] Supportare lambda, symbol, proc
- [ ] Test: before callback eseguito
- [ ] Test: after callback eseguito
- [ ] Test: ordine esecuzione callback

#### Criterio di successo
```ruby
transition :publish,
  from: :draft,
  to: :published,
  before: :set_published_at,
  after: :notify_subscribers

def set_published_at
  self.published_at = Time.current
end

article.to_published!  # Da implementare in step 17
article.published_at  # => Time.current
```

#### Riferimento
Implementation plan: linee 909-1014

---

### Step 17: Query Methods (in_*, was_*, can_to_*)

**Milestone:** 4
**Dipende da:** Step 16
**Tempo stimato:** 3 ore
**Status:** ⬜ Todo

#### Obiettivo
Generare metodi dinamici per query stato e transizioni.

#### File da modificare
- `lib/better_model/state_machine.rb`
- `test/better_model/state_machine_test.rb`

#### Checklist implementazione
- [ ] Implementare `define_state_machine_methods(column, machine)`
- [ ] Generare `in_#{state}?` per ogni stato
- [ ] Generare `was_#{state}?` per stato precedente
- [ ] Generare `to_#{state}!` per transizioni
- [ ] Generare `can_to_#{state}?` per check transizioni
- [ ] Test: metodi query stato
- [ ] Test: metodi transizione
- [ ] Test: metodi can check

#### Criterio di successo
```ruby
article.status = :draft
article.in_draft?  # => true
article.can_to_published?  # => false (mancano condizioni)

article.title = "Test"
article.content = "Content"
article.can_to_published?  # => true
article.to_published!
article.in_published?  # => true
article.was_draft?  # => true
```

#### Riferimento
Implementation plan: linee 628-665

---

### Step 18: Transaction Wrapping + Error Handling

**Milestone:** 4
**Dipende da:** Step 17
**Tempo stimato:** 2 ore
**Status:** ⬜ Todo

#### Obiettivo
Wrappare transizioni in transaction e gestire errori.

#### File da modificare
- `lib/better_model/state_machine/transition.rb`
- `test/better_model/state_machine_test.rb`

#### Checklist implementazione
- [ ] Wrappare `execute` in `record.class.transaction`
- [ ] Creare `InvalidTransitionError` custom exception
- [ ] Raise error se transizione non valida
- [ ] Test: rollback su errore
- [ ] Test: InvalidTransitionError con messaggio chiaro

#### Criterio di successo
```ruby
article.status = :published
begin
  article.to_draft!  # No transition defined
rescue BetterModel::StateMachine::InvalidTransitionError => e
  e.message  # => "Invalid transition from published to draft for Article#123"
end

article.status  # => :published (rollback)
```

#### Riferimento
Implementation plan: linee 799-830

---

## MILESTONE 5: Statusable (Step 19-20)

### Step 19: Status Definition + Dynamic Calculation

**Milestone:** 5
**Dipende da:** Step 2
**Tempo stimato:** 2 ore
**Status:** ⬜ Todo

#### Obiettivo
Creare concern per stati derivati calcolati dinamicamente.

#### File da creare
- `lib/better_model/statusable.rb`
- `test/better_model/statusable_test.rb`

#### Checklist implementazione
- [ ] Creare modulo `BetterModel::Statusable`
- [ ] Implementare `is(status_name, condition)`
- [ ] Condition può essere lambda o proc
- [ ] Metodo `is_#{status}?` generato dinamicamente
- [ ] Registry `is_definitions` per tracking
- [ ] Test: status calcolato da lambda
- [ ] Test: multipli status

#### Criterio di successo
```ruby
class Article < ApplicationRecord
  include BetterModel::Statusable

  is :publishable, -> { status == :draft && valid?(:publication) }
  is :stale, -> { updated_at < 1.month.ago }
end

article = Article.new(status: :draft, title: "Test", updated_at: 2.months.ago)
article.is_publishable?  # => true
article.is_stale?  # => true
```

#### Riferimento
Implementation plan: linee 1050-1120

---

### Step 20: Status Scopes + status_checks Method

**Milestone:** 5
**Dipende da:** Step 19
**Tempo stimato:** 1 ora
**Status:** ⬜ Todo

#### Obiettivo
Generare scope per ogni status e metodo `status_checks`.

#### File da modificare
- `lib/better_model/statusable.rb`
- `test/better_model/statusable_test.rb`

#### Checklist implementazione
- [ ] Generare scope `#{status_name}` per ogni status
- [ ] Implementare `status_checks` che ritorna hash
- [ ] Test: scope status
- [ ] Test: status_checks con tutti gli stati

#### Criterio di successo
```ruby
is :publishable, -> { status == :draft && valid? }
is :visible, -> { status == :published }

Article.publishable  # => scope ActiveRecord
article.status_checks  # => { publishable: true, visible: false }
```

#### Riferimento
Implementation plan: linee 1029-1072

---

## MILESTONE 6: Searchable Base (Step 21-25)

### Step 21: Predicate Registry + Validation

**Milestone:** 6
**Dipende da:** Step 2
**Tempo stimato:** 2 ore
**Status:** ⬜ Todo

#### Obiettivo
Creare registry predicati e sistema validazione base.

#### File da creare
- `lib/better_model/searchable.rb`
- `test/better_model/searchable_test.rb`

#### Checklist implementazione
- [ ] Creare modulo `BetterModel::Searchable`
- [ ] Class attribute `complex_predicates_registry`
- [ ] Validare che classe sia ActiveRecord::Base
- [ ] Scope base: `id_in`, `created_at_between`
- [ ] Implementare `validate_predicates!(predicates)`
- [ ] Test: inclusione in non-ActiveRecord raise error
- [ ] Test: predicate inesistente raise error

#### Criterio di successo
```ruby
class Article < ApplicationRecord
  include BetterModel::Searchable
end

Article.id_in([1, 2, 3])  # => scope
Article.search(invalid_pred: "value")  # => ArgumentError
```

#### Riferimento
Implementation plan: linee 1327-1400

---

### Step 22: String Predicates

**Milestone:** 6
**Dipende da:** Step 21
**Tempo stimato:** 3 ore
**Status:** ⬜ Todo

#### Obiettivo
Implementare tutti i predicati per campi string/text.

#### File da modificare
- `lib/better_model/searchable.rb`
- `test/better_model/searchable_test.rb`

#### Checklist implementazione
- [ ] Implementare `define_string_predicates(*fields)`
- [ ] Predicati: `_eq`, `_not_eq`, `_matches`
- [ ] Predicati: `_start`, `_end`, `_cont`, `_not_cont`
- [ ] Predicati: `_i_cont`, `_not_i_cont` (case-insensitive)
- [ ] Predicati: `_in`, `_not_in`, `_present`, `_blank`, `_null`
- [ ] Test per ogni predicato

#### Criterio di successo
```ruby
define_string_predicates :title, :content

Article.title_eq("Test")  # => scope WHERE title = 'Test'
Article.title_i_cont("rails")  # => scope WHERE LOWER(title) LIKE '%rails%'
Article.title_in(["A", "B"])  # => scope WHERE title IN ('A', 'B')
```

#### Riferimento
Implementation plan: linee 1580-1700

---

### Step 23: Numeric Predicates

**Milestone:** 6
**Dipende da:** Step 22
**Tempo stimato:** 2 ore
**Status:** ⬜ Todo

#### Obiettivo
Implementare predicati per campi numerici.

#### File da modificare
- `lib/better_model/searchable.rb`
- `test/better_model/searchable_test.rb`

#### Checklist implementazione
- [ ] Implementare `define_numeric_predicates(*fields)`
- [ ] Predicati: `_eq`, `_not_eq`, `_lt`, `_lteq`, `_gt`, `_gteq`
- [ ] Predicati: `_in`, `_not_in`, `_present`, `_null`
- [ ] Test per ogni predicato

#### Criterio di successo
```ruby
define_numeric_predicates :view_count, :price

Article.view_count_gt(100)  # => scope WHERE view_count > 100
Article.price_lteq(50)  # => scope WHERE price <= 50
Article.view_count_in([10, 20, 30])  # => scope WHERE view_count IN (10, 20, 30)
```

#### Riferimento
Implementation plan: linee 1700-1780

---

### Step 24: Date + Boolean Predicates

**Milestone:** 6
**Dipende da:** Step 23
**Tempo stimato:** 2 ore
**Status:** ⬜ Todo

#### Obiettivo
Implementare predicati per date e boolean.

#### File da modificare
- `lib/better_model/searchable.rb`
- `test/better_model/searchable_test.rb`

#### Checklist implementazione
- [ ] Implementare `define_date_predicates(*fields)`
- [ ] Date predicati: `_eq`, `_not_eq`, `_lt`, `_lteq`, `_gt`, `_gteq`
- [ ] Date predicati: `_in`, `_not_in`, `_present`, `_null`
- [ ] Implementare `define_boolean_predicates(*fields)`
- [ ] Boolean predicati: `_eq`, `_not_eq`, `_true`, `_false`
- [ ] Test per ogni tipo

#### Criterio di successo
```ruby
define_date_predicates :published_at, :created_at
define_boolean_predicates :active, :verified

Article.published_at_gteq(1.month.ago)  # => scope
Article.active_true  # => scope WHERE active = true
Article.verified_false  # => scope WHERE verified = false
```

#### Riferimento
Implementation plan: linee 1780-1860

---

### Step 25: Complex Predicates (register_complex_predicate)

**Milestone:** 6
**Dipende da:** Step 24
**Tempo stimato:** 2 ore
**Status:** ⬜ Todo

#### Obiettivo
Permettere registrazione di predicati custom complessi.

#### File da modificare
- `lib/better_model/searchable.rb`
- `test/better_model/searchable_test.rb`

#### Checklist implementazione
- [ ] Implementare `register_complex_predicate(name, &block)`
- [ ] Salvare block in `complex_predicates_registry`
- [ ] Creare scope dinamico che usa il registry
- [ ] Test: predicato complesso con query custom
- [ ] Test: predicato con parametri multipli

#### Criterio di successo
```ruby
register_complex_predicate :popular do |relation, days|
  relation
    .where('published_at >= ?', days.days.ago)
    .where('view_count > ?', 100)
end

Article.popular(7)  # => scope con query complessa
```

#### Riferimento
Implementation plan: linee 1353-1365, 1920-1940

---

## MILESTONE 7: Searchable Advanced (Step 26-29)

### Step 26: Search Method + Pagination

**Milestone:** 7
**Dipende da:** Step 25
**Tempo stimato:** 3 ore
**Status:** ⬜ Todo

#### Obiettivo
Implementare metodo `search` con pagination integrata.

#### File da modificare
- `lib/better_model/searchable.rb`
- `test/better_model/searchable_test.rb`

#### Checklist implementazione
- [ ] Implementare `search(predicates, page:, per_page:, ...)`
- [ ] Implementare `advanced_search(predicates)`
- [ ] Implementare `paginate(relation, page:, per_page:)`
- [ ] Aggiungere metodi helper: `current_page`, `total_pages`, `total_count`
- [ ] Memoizzare `total_count` per performance
- [ ] Test: search con predicati multipli
- [ ] Test: pagination info

#### Criterio di successo
```ruby
results = Article.search(
  { title_i_cont: 'rails', status_eq: 'published' },
  page: 2,
  per_page: 20
)

results.current_page  # => 2
results.total_pages  # => 5
results.total_count  # => 97
```

#### Riferimento
Implementation plan: linee 1393-1450, 1453-1479

---

### Step 27: Includes/Joins Support

**Milestone:** 7
**Dipende da:** Step 26
**Tempo stimato:** 2 ore
**Status:** ⬜ Todo

#### Obiettivo
Aggiungere supporto per `includes` e `joins` nel search.

#### File da modificare
- `lib/better_model/searchable.rb`
- `test/better_model/searchable_test.rb`

#### Checklist implementazione
- [ ] Aggiungere parametri `includes:`, `joins:` a `search`
- [ ] Applicare joins PRIMA di includes (per ORDER BY)
- [ ] Supportare array e nested hash Rails
- [ ] Test: includes eager loading
- [ ] Test: joins per filtering
- [ ] Test: nested associations

#### Criterio di successo
```ruby
Article.search(
  { title_i_cont: 'rails' },
  includes: [:author, { comments: :user }],
  joins: { business_unit: :user }
)
```

#### Riferimento
Implementation plan: linee 1412-1416, 4166-4196

---

### Step 28: Order Parameter (Symbol, Hash, Array)

**Milestone:** 7
**Dipende da:** Step 27
**Tempo stimato:** 3 ore
**Status:** ⬜ Todo

#### Obiettivo
Implementare parametro `order` unificato con supporto multipli formati.

#### File da modificare
- `lib/better_model/searchable.rb`
- `test/better_model/searchable_test.rb`

#### Checklist implementazione
- [ ] Aggiungere parametro `order:` a `search`
- [ ] Implementare `apply_ordering(relation, order_value)`
- [ ] Implementare `apply_scope_ordering(relation, scope_name)`
- [ ] Implementare `apply_rails_ordering(relation, order_hash)`
- [ ] Implementare `is_orderable_scope?(scope_name)`
- [ ] Supporto Symbol (Orderable scope)
- [ ] Supporto Hash (Rails standard)
- [ ] Supporto Array (misto)
- [ ] Test per ogni formato

#### Criterio di successo
```ruby
# Symbol
Article.search({}, order: :published_at_newest)

# Hash
Article.search({}, order: { published_at: :desc, view_count: :asc })

# Array
Article.search({}, order: [:published_at_newest, { view_count: :desc }])
```

#### Riferimento
Implementation plan: linee 1418-1420, 1453-1503

---

### Step 29: Required Predicates + Scope Security

**Milestone:** 7
**Dipende da:** Step 28
**Tempo stimato:** 2 ore
**Status:** ⬜ Todo

#### Obiettivo
Implementare `require_predicates_for_scope` per sicurezza multitenancy.

#### File da modificare
- `lib/better_model/searchable.rb`
- `test/better_model/searchable_test.rb`

#### Checklist implementazione
- [ ] Class attribute `required_predicates_by_scope`
- [ ] Implementare `require_predicates_for_scope(scope_name, *predicates)`
- [ ] Implementare `validate_required_predicates!(predicates, scope)`
- [ ] Creare `RequiredPredicateError` exception
- [ ] Aggiungere parametro `scope:` a `search`
- [ ] Test: predicati mancanti raise error
- [ ] Test: predicati nil raise error
- [ ] Test: scope :default no validation

#### Criterio di successo
```ruby
class Booking < ApplicationRecord
  include BetterModel::Searchable

  require_predicates_for_scope :doctor_dashboard, :doctor_id_eq, :organization_id_eq
end

Booking.search({ status_eq: 'pending' }, scope: :doctor_dashboard)
# => RequiredPredicateError: "Required predicates missing for scope 'doctor_dashboard': doctor_id_eq, organization_id_eq"

Booking.search(
  { doctor_id_eq: 123, organization_id_eq: 456, status_eq: 'pending' },
  scope: :doctor_dashboard
)
# => Funziona correttamente
```

#### Riferimento
Implementation plan: linee 1381-1391, 1490-1506, 4201-4260

---

## MILESTONE 8: Orderable (Step 30-34)

### Step 30: Ordering Scope Base

**Milestone:** 8
**Dipende da:** Step 2
**Tempo stimato:** 2 ore
**Status:** ⬜ Todo

#### Obiettivo
Creare base Orderable con scope generici e define_ordering_scope.

#### File da creare
- `lib/better_model/orderable.rb`
- `test/better_model/orderable_test.rb`

#### Checklist implementazione
- [ ] Creare modulo `BetterModel::Orderable`
- [ ] Class attribute `orderable_scopes` (Set)
- [ ] Validare che classe sia ActiveRecord::Base
- [ ] Implementare scope `order_by(field, direction)`
- [ ] Implementare scope `multiple_order(order_hash)`
- [ ] Implementare `define_ordering_scope(field_name)`
- [ ] Generare scope: `_direction`, `_asc`, `_desc`
- [ ] Metodo `register_orderable_scopes(*scope_names)`
- [ ] Test: scope base
- [ ] Test: define_ordering_scope

#### Criterio di successo
```ruby
class Article < ApplicationRecord
  include BetterModel::Orderable

  define_ordering_scope :title
end

Article.order_by(:title, 'asc')  # => scope
Article.title_asc  # => scope ORDER BY title ASC
Article.title_desc  # => scope ORDER BY title DESC
Article.title_direction('desc')  # => scope ORDER BY title DESC
```

#### Riferimento
Implementation plan: linee 2064-2133, 2282-2291

---

### Step 31: String Ordering (Case-Insensitive)

**Milestone:** 8
**Dipende da:** Step 30
**Tempo stimato:** 2 ore
**Status:** ⬜ Todo

#### Obiettivo
Implementare ordinamento string con supporto case-insensitive.

#### File da modificare
- `lib/better_model/orderable.rb`
- `test/better_model/orderable_test.rb`

#### Checklist implementazione
- [ ] Implementare `define_string_ordering(*fields)`
- [ ] Chiamare `define_ordering_scope` internamente
- [ ] Generare scope aggiuntivi: `_i_direction`, `_i_asc`, `_i_desc`
- [ ] Usare `Arel::Nodes::NamedFunction` per LOWER()
- [ ] Registrare scope in `orderable_scopes`
- [ ] Test: ordinamento case-sensitive
- [ ] Test: ordinamento case-insensitive

#### Criterio di successo
```ruby
define_string_ordering :title, :description

Article.title_asc  # => ORDER BY title ASC
Article.title_i_asc  # => ORDER BY LOWER(title) ASC
Article.title_i_desc  # => ORDER BY LOWER(title) DESC
```

#### Riferimento
Implementation plan: linee 2144-2178

---

### Step 32: Numeric Ordering (NULLS LAST/FIRST Cross-DB)

**Milestone:** 8
**Dipende da:** Step 31
**Tempo stimato:** 3 ore
**Status:** ⬜ Todo

#### Obiettivo
Implementare ordinamento numeric con gestione NULL cross-database.

#### File da modificare
- `lib/better_model/orderable.rb`
- `test/better_model/orderable_test.rb`

#### Checklist implementazione
- [ ] Implementare `define_numeric_ordering(*fields)`
- [ ] Generare scope: `_nulls_last`, `_nulls_first`
- [ ] Implementare `order_with_nulls_handling(field, direction, nulls_position)`
- [ ] PostgreSQL/SQLite: usare NULLS LAST/FIRST nativo
- [ ] MySQL/MariaDB: simulare con CASE WHEN
- [ ] Fallback per DB sconosciuti con warning
- [ ] Test: PostgreSQL NULLS LAST
- [ ] Test: MySQL CASE simulation
- [ ] Test: fallback con warning

#### Criterio di successo
```ruby
define_numeric_ordering :view_count, :price

Article.view_count_nulls_last('desc')  # => ORDER BY view_count DESC NULLS LAST
Article.price_nulls_first('asc')  # => ORDER BY price ASC NULLS FIRST

# Cross-database compatibility
# PostgreSQL: ORDER BY view_count DESC NULLS LAST
# MySQL: ORDER BY CASE WHEN view_count IS NULL THEN 1 ELSE 0 END, view_count DESC
```

#### Riferimento
Implementation plan: linee 2181-2236

---

### Step 33: Date Ordering (newest/oldest)

**Milestone:** 8
**Dipende da:** Step 32
**Tempo stimato:** 1 ora
**Status:** ⬜ Todo

#### Obiettivo
Implementare ordinamento date con helper semantici.

#### File da modificare
- `lib/better_model/orderable.rb`
- `test/better_model/orderable_test.rb`

#### Checklist implementazione
- [ ] Implementare `define_date_ordering(*fields)`
- [ ] Generare scope: `_newest`, `_oldest`
- [ ] `_newest` = ORDER BY field DESC
- [ ] `_oldest` = ORDER BY field ASC
- [ ] Test: newest (più recente prima)
- [ ] Test: oldest (più vecchio prima)

#### Criterio di successo
```ruby
define_date_ordering :published_at, :created_at

Article.published_at_newest  # => ORDER BY published_at DESC
Article.created_at_oldest  # => ORDER BY created_at ASC
```

#### Riferimento
Implementation plan: linee 2238-2257

---

### Step 34: Auto-Detection + Registry Integration

**Milestone:** 8
**Dipende da:** Step 33
**Tempo stimato:** 2 ore
**Status:** ⬜ Todo

#### Obiettivo
Implementare auto-detection del tipo campo e completare registry.

#### File da modificare
- `lib/better_model/orderable.rb`
- `test/better_model/orderable_test.rb`

#### Checklist implementazione
- [ ] Implementare `define_auto_ordering(field_name)`
- [ ] Auto-detect tipo da `columns_hash[field_name].type`
- [ ] String/Text → `define_string_ordering`
- [ ] Integer/Decimal/Float → `define_numeric_ordering`
- [ ] Date/DateTime → `define_date_ordering`
- [ ] Fallback → `define_ordering_scope`
- [ ] Implementare `define_orderable_fields(*fields)` bulk helper
- [ ] Test: auto-detection per ogni tipo
- [ ] Test: registry popolato correttamente

#### Criterio di successo
```ruby
define_orderable_fields :title, :view_count, :published_at
# Auto-rileva tipi e genera scope appropriati

Article.orderable_scopes
# => Set[:title_asc, :title_desc, :title_i_asc, :view_count_asc, :view_count_nulls_last, :published_at_newest, ...]
```

#### Riferimento
Implementation plan: linee 2241-2280

---

## MILESTONE 9: Integration & Polish (Step 35-37)

### Step 35: Full Integration Test

**Milestone:** 9
**Dipende da:** Step 34
**Tempo stimato:** 3 ore
**Status:** ⬜ Todo

#### Obiettivo
Creare test completo con tutti i concern integrati insieme.

#### File da creare
- `test/integration/full_integration_test.rb`

#### Checklist implementazione
- [ ] Creare modello Article con TUTTI i concern
- [ ] Test: Attributes + Validations
- [ ] Test: StateMachine + Statusable
- [ ] Test: Searchable + Orderable
- [ ] Test: Interazione tra concern
- [ ] Test: Search completo con tutti i parametri
- [ ] Test: Performance con 1000+ record

#### Criterio di successo
```ruby
class Article < ApplicationRecord
  include BetterModel::Attributes
  include BetterModel::Validations
  include BetterModel::StateMachine
  include BetterModel::Statusable
  include BetterModel::Searchable
  include BetterModel::Orderable

  # Configura tutti i concern
  typed_attribute :metadata, :better_json
  required :title, :content

  state_machine :status do
    initial :draft
    states :draft, :in_review, :published
    transition :publish, from: :draft, to: :published
  end

  is :publishable, -> { in_draft? && valid?(:publication) }

  define_auto_predicates :title, :content, :status
  define_orderable_fields :title, :published_at
end

# Test search completo
results = Article.search(
  { title_i_cont: 'rails', status_eq: 'published' },
  page: 1,
  per_page: 20,
  includes: [:author],
  order: [:published_at_newest, { view_count: :desc }],
  scope: :default
)
```

#### Riferimento
Implementation plan: linee 4287-4370

---

### Step 36: Documentation + Examples

**Milestone:** 9
**Dipende da:** Step 35
**Tempo stimato:** 4 ore
**Status:** ⬜ Todo

#### Obiettivo
Documentare API completa con esempi reali.

#### File da creare/modificare
- `README.md` (completo)
- `docs/attributes.md`
- `docs/validations.md`
- `docs/state_machine.md`
- `docs/statusable.md`
- `docs/searchable.md`
- `docs/orderable.md`
- `CHANGELOG.md`

#### Checklist implementazione
- [ ] README con quick start
- [ ] Guida per ogni concern
- [ ] Esempi real-world (blog, e-commerce, booking)
- [ ] API reference completa
- [ ] Troubleshooting common issues
- [ ] Migration guide from other gems
- [ ] CHANGELOG per v0.1.0

#### Criterio di successo
```bash
# README ha quick start funzionante
# Ogni concern ha doc dedicata
# Esempi sono copy-paste ready
```

#### Riferimento
Implementation plan: tutto il documento

---

### Step 37: Performance Optimization + Benchmarks

**Milestone:** 9
**Dipende da:** Step 36
**Tempo stimato:** 3 ore
**Status:** ⬜ Todo

#### Obiettivo
Ottimizzare performance e creare benchmark suite.

#### File da creare
- `benchmark/attributes_benchmark.rb`
- `benchmark/search_benchmark.rb`
- `benchmark/state_machine_benchmark.rb`

#### Checklist implementazione
- [ ] Benchmark Attributes vs ActiveRecord nativo
- [ ] Benchmark Search vs Ransack
- [ ] Benchmark StateMachine vs AASM
- [ ] Ottimizzare query N+1
- [ ] Ottimizzare memoization
- [ ] Profilare con ruby-prof
- [ ] Documentare performance results

#### Criterio di successo
```bash
ruby benchmark/search_benchmark.rb

BetterModel::Searchable: 1000 searches in 0.15s
Ransack: 1000 searches in 0.45s
Speedup: 3x faster
```

#### Riferimento
Best practices Rails performance

---

## Tracking Progress

Usa questo checklist per tracciare il progresso:

```bash
# Esempio tracking
echo "Step 1: ✅ Completato"
echo "Step 2: 🚧 In corso"
echo "Step 3: ⬜ Todo"
```

### Progress Overview

- **Milestone 1 (Setup):** 0/3 step completati
- **Milestone 2 (Attributes):** 0/5 step completati
- **Milestone 3 (Validations):** 0/4 step completati
- **Milestone 4 (StateMachine):** 0/6 step completati
- **Milestone 5 (Statusable):** 0/2 step completati
- **Milestone 6 (Searchable Base):** 0/5 step completati
- **Milestone 7 (Searchable Advanced):** 0/4 step completati
- **Milestone 8 (Orderable):** 0/5 step completati
- **Milestone 9 (Integration):** 0/3 step completati

**Totale:** 0/37 step completati (0%)

---

## Note

- Ogni step è indipendente dove possibile
- Step di una milestone possono essere parallelizzati
- Test devono passare prima di procedere allo step successivo
- Commit dopo ogni step completato con messaggio chiaro
