# Searchable - Unified Search Interface

## Panoramica

**Versione**: 3.0.0 | **Tipo**: Opt-in

Searchable è un orchestratore che unifica **Predicable** (filtering), **Sortable** (ordering), e **pagination** in un'unica interfaccia coerente. Invece di chain manuale di predicate/sort scopes, fornisce un metodo `search()` che gestisce tutto con validation, security enforcement, e DoS protection.

**Caratteristiche principali**:
- Unified API: un metodo per filtering + sorting + pagination
- Orchestrazione Predicable e Sortable
- OR conditions per logica booleana complessa
- Security enforcement: richiede predicates specifici
- Pagination con DoS protection
- Association eager loading (includes/preload/eager_load)
- Validation con error messages
- Chainable (ritorna ActiveRecord::Relation)
- Thread-safe

**Requirements**:
- Predicable configurato (define filterable fields)
- Sortable configurato (define orderable fields)
- Searchable configuration block

**Opt-in**: Searchable NON è attivo di default. Richiede Predicable + Sortable + configurazione esplicita.

## The Orchestration Pattern

### 1. Setup Base - Predicable + Sortable + Searchable

**Cosa fa**: Configura il model con filtering, sorting, e search orchestration.

**Quando usarlo**: Quando vuoi un'interfaccia unificata per search con validation e security.

**Esempio**:
```ruby
class Article < ApplicationRecord
  include BetterModel

  # Step 1: Predicable (filtering capabilities)
  predicates :title, :content, :status, :view_count, :published_at

  # Step 2: Sortable (ordering capabilities)
  sort :title, :view_count, :published_at, :created_at

  # Step 3: Searchable (orchestration layer)
  searchable do
    per_page 25
    max_per_page 100
    default_order [:sort_published_at_desc, :sort_created_at_desc]
    security :status_required, [:status_eq]
  end
end

# Usage: unified interface
Article.search(
  { title_cont: "Rails", status_eq: "published", view_count_gt: 100 },
  pagination: { page: 1, per_page: 25 },
  orders: [:sort_published_at_desc]
)

# Equivalente a (manuale):
Article.title_cont("Rails")
       .status_eq("published")
       .view_count_gt(100)
       .sort_published_at_desc
       .page(1).per(25)
```

### 2. Configurazione Pagination

**Cosa fa**: Configura default e limiti per pagination con DoS protection.

**Quando usarlo**: Sempre, per prevenire query eccessive e DoS attacks.

**Esempio**:
```ruby
class Article < ApplicationRecord
  predicates :title, :status
  sort :title, :published_at

  searchable do
    per_page 25              # Default per page (se omesso in query)
    max_per_page 100         # Max allowed (capped, DoS protection)
    max_page 1000            # Max page number (DoS protection)
  end
end

# Usage
Article.search({}, pagination: { page: 1, per_page: 50 })
# => LIMIT 50 OFFSET 0

# Capped at max_per_page
Article.search({}, pagination: { page: 1, per_page: 500 })
# => LIMIT 100 OFFSET 0 (capped a 100)

# Default per_page se omesso
Article.search({}, pagination: { page: 2 })
# => LIMIT 25 OFFSET 25 (usa per_page default)
```

### 3. Configurazione Default Order

**Cosa fa**: Specifica ordering di default quando `orders:` non è specificato.

**Quando usarlo**: Per consistenza e ordering predicibile quando user non specifica sort.

**Esempio**:
```ruby
class Article < ApplicationRecord
  predicates :title, :status
  sort :title, :published_at, :created_at

  searchable do
    default_order [:sort_published_at_desc, :sort_created_at_desc]
  end
end

# Senza orders: usa default_order
Article.search({ status_eq: "published" })
# SQL: ORDER BY published_at DESC, created_at DESC

# Con orders: override default
Article.search(
  { status_eq: "published" },
  orders: [:sort_title_asc]
)
# SQL: ORDER BY title ASC
```

### 4. Configurazione Security Rules

**Cosa fa**: Definisce regole che richiedono predicates specifici con valori validi.

**Quando usarlo**: Multi-tenant apps, role-based access, public APIs con security requirements.

**Esempio**:
```ruby
class Document < ApplicationRecord
  predicates :title, :content, :tenant_id, :status
  sort :title, :created_at

  searchable do
    # Single required predicate
    security :status_required, [:status_eq]

    # Multiple required predicates
    security :tenant_required, [:tenant_id_eq]
    security :tenant_and_status, [:tenant_id_eq, :status_eq]
  end
end

# Valid: required predicate present
Document.search(
  { tenant_id_eq: 123, title_cont: "Test" },
  security: :tenant_required
)  # ✅ OK

# Invalid: missing required predicate
Document.search(
  { title_cont: "Test" },
  security: :tenant_required
)  # ❌ Raises InvalidSecurityError
```

### 5. DoS Protection Limits

**Cosa fa**: Limita numero di predicates, OR conditions, e pages per prevenire DoS.

**Quando usarlo**: Public APIs, user-facing search, prevenzione abusi.

**Esempio**:
```ruby
class Article < ApplicationRecord
  predicates :title, :status, :view_count, :published_at
  sort :title, :created_at

  searchable do
    max_per_page 100         # Max records per page
    max_page 1000            # Max page number
    max_predicates 20        # Max predicates per search
    max_or_conditions 5      # Max OR condition groups
  end
end

# Valid: entro limiti
Article.search({
  title_cont: "Rails",
  status_eq: "published"
})  # ✅ 2 predicates OK

# Invalid: troppi predicates
Article.search({
  field1: "a", field2: "b", ..., field25: "z"
})  # ❌ Raises error se > 20 predicates
```

## Search Method Usage

### 6. Empty Search

**Cosa fa**: Recupera tutti i record con default_order se configurato.

**Quando usarlo**: "Show all" functionality, base per filtering dinamico.

**Esempio**:
```ruby
class Article < ApplicationRecord
  predicates :title, :status
  sort :published_at

  searchable do
    default_order [:sort_published_at_desc]
  end
end

# Empty predicates hash
articles = Article.search({})
# SQL: SELECT * FROM articles ORDER BY published_at DESC

# Equivalente
articles = Article.all.sort_published_at_desc
```

### 7. Single Predicate

**Cosa fa**: Filtra con un singolo predicate.

**Quando usarlo**: Simple filtering su un campo.

**Esempio**:
```ruby
# Single predicate
Article.search({ status_eq: "published" })
# SQL: WHERE status = 'published'

# Con pagination
Article.search(
  { status_eq: "published" },
  pagination: { page: 1, per_page: 25 }
)
# SQL: WHERE status = 'published' LIMIT 25 OFFSET 0
```

### 8. Multiple Predicates (AND Logic)

**Cosa fa**: Combina multipli predicates con AND logic.

**Quando usarlo**: Filtering complesso su multipli campi.

**Esempio**:
```ruby
Article.search({
  status_eq: "published",
  view_count_gteq: 100,
  published_at_gt: 1.week.ago,
  title_cont: "Rails"
})
# SQL: WHERE status = 'published'
#       AND view_count >= 100
#       AND published_at > '2025-11-04'
#       AND title LIKE '%Rails%'

# Valori nil/empty sono skipped
Article.search({
  status_eq: "published",
  title_cont: nil,        # Skipped
  view_count_gt: ""       # Skipped
})
# SQL: WHERE status = 'published' (solo)
```

### 9. Search con Sorting

**Cosa fa**: Applica ordering con uno o più sort scopes.

**Quando usarlo**: User-selectable sorting, primary/secondary/tertiary sorts.

**Esempio**:
```ruby
# Single sort
Article.search(
  { status_eq: "published" },
  orders: [:sort_published_at_desc]
)
# SQL: ORDER BY published_at DESC

# Multiple sorts (applied in order)
Article.search(
  { status_eq: "published" },
  orders: [:sort_view_count_desc, :sort_title_asc]
)
# SQL: ORDER BY view_count DESC, title ASC

# Invalid sort scope
Article.search({}, orders: [:nonexistent_sort])
# ❌ Raises InvalidOrderError
```

### 10. Search Combined (Full-Featured)

**Cosa fa**: Usa tutti i parametri insieme: predicates + pagination + sorting + eager loading.

**Quando usarlo**: Feature-complete search interfaces, APIs complesse.

**Esempio**:
```ruby
Article.search(
  {
    status_eq: "published",
    title_cont: "Rails",
    view_count_between: [50, 200],
    published_at_gteq: 1.month.ago
  },
  pagination: { page: 1, per_page: 25 },
  orders: [:sort_published_at_desc, :sort_view_count_desc],
  includes: [:author, { comments: :user }]
)
# Single optimized SQL query:
# SELECT * FROM articles
# WHERE status = 'published'
#   AND title LIKE '%Rails%'
#   AND view_count BETWEEN 50 AND 200
#   AND published_at >= '2025-10-11'
# ORDER BY published_at DESC, view_count DESC
# LIMIT 25 OFFSET 0
```

### 11. Chainability con ActiveRecord

**Cosa fa**: `search()` ritorna ActiveRecord::Relation, quindi chainable.

**Quando usarlo**: Quando serve aggiungere filtering/logic extra dopo search.

**Esempio**:
```ruby
# Chain con AR methods
articles = Article.search({ status_eq: "published" })
                  .includes(:tags)
                  .limit(10)

# Chain con predicates
articles = Article.search({ status_eq: "published" })
                  .view_count_gt(100)  # Additional predicate

# Chain con sort scopes
articles = Article.search({ status_eq: "published" })
                  .sort_title_asc

# Count
count = Article.search({ status_eq: "published" }).count

# Pluck
titles = Article.search({ status_eq: "published" }).pluck(:title)

# Exists?
exists = Article.search({ status_eq: "published" }).exists?
```

## OR Conditions

### 12. OR Base

**Cosa fa**: Special `:or` key per OR logic tra predicates.

**Quando usarlo**: "Match any" filtering, text search su multipli campi.

**Esempio**:
```ruby
# Simple OR: title contains "Ruby" OR "Rails"
Article.search(
  or: [
    { title_cont: "Ruby" },
    { title_cont: "Rails" }
  ]
)
# SQL: WHERE (title LIKE '%Ruby%' OR title LIKE '%Rails%')

# Text search su multipli campi
Article.search(
  or: [
    { title_cont: query },
    { content_cont: query },
    { author_name_cont: query }
  ]
)
# SQL: WHERE (title LIKE '%...%' OR content LIKE '%...%' OR ...)
```

### 13. OR con AND Predicates

**Cosa fa**: Combina OR conditions con AND predicates.

**Quando usarlo**: "Match any" + required filters.

**Esempio**:
```ruby
# (High views OR featured) AND published
Article.search({
  or: [
    { view_count_gt: 100 },
    { featured_eq: true }
  ],
  status_eq: "published"  # AND condition
})
# SQL: WHERE ((view_count > 100 OR featured = true)
#             AND status = 'published')

# Multiple fields search + status filter
Article.search({
  or: [
    { title_i_cont: query },
    { content_i_cont: query }
  ],
  status_eq: "published",
  published_at_gteq: 1.month.ago
})
```

### 14. OR Complesso (Multiple Predicates per Group)

**Cosa fa**: Ogni OR group può contenere multiple predicates (AND within group).

**Quando usarlo**: Complex business logic, multiple condition sets.

**Esempio**:
```ruby
# (Published with high views) OR (draft and featured)
Article.search(
  or: [
    { status_eq: "published", view_count_gt: 100 },
    { status_eq: "draft", featured_eq: true }
  ]
)
# SQL: WHERE ((status = 'published' AND view_count > 100)
#             OR (status = 'draft' AND featured = true))

# Complex: multiple OR groups + AND predicates
Article.search({
  or_title: [
    { title_cont: "Ruby" },
    { title_cont: "Rails" }
  ],
  or_priority: [
    { view_count_gt: 100 },
    { featured_eq: true }
  ],
  status_eq: "published"
})
```

## Security Enforcement

### 15. Security: Multi-Tenant Scoping

**Cosa fa**: Forza presenza di tenant_id in tutte le query per data isolation.

**Quando usarlo**: Multi-tenant SaaS apps dove data isolation è critica.

**Esempio**:
```ruby
class Document < ApplicationRecord
  predicates :title, :content, :tenant_id, :status
  sort :title, :created_at

  searchable do
    security :tenant_required, [:tenant_id_eq]
  end
end

# Controller enforces tenant scoping
class DocumentsController < ApplicationController
  def index
    @documents = Document.search(
      search_params.merge(tenant_id_eq: current_tenant.id),
      pagination: pagination_params,
      security: :tenant_required  # Enforces
    )
  end

  private

  def search_params
    params.permit(:title_cont, :status_eq).to_h
  end
end

# Valid
Document.search(
  { tenant_id_eq: 123, title_cont: "Test" },
  security: :tenant_required
)  # ✅

# Invalid: missing tenant_id
Document.search(
  { title_cont: "Test" },
  security: :tenant_required
)  # ❌ Raises InvalidSecurityError
```

### 16. Security Validation Rules

**Cosa fa**: Valida che required predicates abbiano valori non-nil e non-empty.

**Quando usarlo**: Sempre con security rules per garantire enforcement corretto.

**Esempio**:
```ruby
class Article < ApplicationRecord
  searchable do
    security :status_required, [:status_eq]
  end
end

# Valid: non-nil, non-empty value
Article.search(
  { status_eq: "published" },
  security: :status_required
)  # ✅

# Invalid: nil value
Article.search(
  { status_eq: nil },
  security: :status_required
)  # ❌ Raises InvalidSecurityError

# Invalid: empty string
Article.search(
  { status_eq: "" },
  security: :status_required
)  # ❌ Raises InvalidSecurityError

# Valid: false is allowed (boolean predicate)
Article.search(
  { featured_eq: false },
  security: :featured_required
)  # ✅ false è valore valido
```

## Association Eager Loading

### 17. Smart Loading - includes:

**Cosa fa**: ActiveRecord sceglie automaticamente tra JOIN o separate queries.

**Quando usarlo**: Default choice, best per most cases.

**Esempio**:
```ruby
# Single association
Article.search(
  { status_eq: "published" },
  includes: [:author]
)

# Multiple associations
Article.search(
  { status_eq: "published" },
  includes: [:author, :comments, :tags]
)

# Nested associations
Article.search(
  { status_eq: "published" },
  includes: [
    :tags,
    { author: :profile },
    { comments: [:user, :likes] }
  ]
)
```

### 18. Separate Queries - preload:

**Cosa fa**: Sempre usa separate queries per ogni association.

**Quando usarlo**: Evitare JOIN complexity, large result sets, ambiguous columns.

**Esempio**:
```ruby
# Forced separate queries
Article.search(
  { status_eq: "published" },
  preload: [:author, :comments]
)
# Query 1: SELECT * FROM articles WHERE status = 'published'
# Query 2: SELECT * FROM users WHERE id IN (...)
# Query 3: SELECT * FROM comments WHERE article_id IN (...)

# Evita ambiguous column errors
Article.search(
  { status_eq: "published" },
  preload: [:author]  # Evita "ambiguous column: created_at"
)
```

### 19. Forced JOIN - eager_load:

**Cosa fa**: Sempre usa LEFT OUTER JOIN.

**Quando usarlo**: Quando serve filter/order by association columns.

**Esempio**:
```ruby
# Forced JOIN
Article.search(
  { status_eq: "published" },
  eager_load: [:author]
)
# SQL: LEFT OUTER JOIN users ON users.id = articles.author_id

# ⚠️ Può causare ambiguous column errors con default_order
# Se entrambi hanno created_at:
Article.search({}, eager_load: [:author])
# ❌ Può fallire se default_order include :sort_created_at_desc

# Soluzione: usa includes: o preload: invece
Article.search({}, includes: [:author])  # ✅
```

## Controller Integration

### 20. Controller Base Pattern

**Cosa fa**: Pattern standard per controller con search, pagination, sorting.

**Quando usarlo**: Standard CRUD index actions con search.

**Esempio**:
```ruby
class ArticlesController < ApplicationController
  def index
    @articles = Article.search(
      search_params,
      pagination: pagination_params,
      orders: order_params
    )
  end

  private

  def search_params
    params.permit(:title_cont, :status_eq, :view_count_gteq).to_h
  end

  def pagination_params
    {
      page: params[:page] || 1,
      per_page: params[:per_page] || 25
    }
  end

  def order_params
    case params[:sort]
    when "newest" then [:sort_published_at_desc]
    when "popular" then [:sort_view_count_desc]
    when "title" then [:sort_title_asc]
    else [:sort_published_at_desc]
    end
  end
end
```

### 21. Controller con Security Enforcement

**Cosa fa**: Controller con multi-tenant security enforcement.

**Quando usarlo**: Multi-tenant apps, role-based access control.

**Esempio**:
```ruby
class DocumentsController < ApplicationController
  before_action :authenticate_user!

  def index
    @documents = Document.search(
      build_search_params,
      pagination: pagination_params,
      security: :tenant_required
    )
  rescue BetterModel::Errors::Searchable::InvalidSecurityError => e
    flash[:error] = "Unauthorized access"
    redirect_to root_path
  end

  private

  def build_search_params
    # Always enforce tenant scoping
    params.permit(:title_cont, :status_eq)
          .to_h
          .merge(tenant_id_eq: current_tenant.id)
  end

  def pagination_params
    { page: params[:page] || 1, per_page: params[:per_page] || 50 }
  end
end
```

### 22. API Controller con Error Handling

**Cosa fa**: API controller con comprehensive error handling.

**Quando usarlo**: RESTful APIs, public APIs, JSON responses.

**Esempio**:
```ruby
class Api::V1::ArticlesController < Api::BaseController
  def index
    @articles = Article.search(
      build_predicates,
      pagination: pagination_params,
      orders: order_params,
      includes: [:author, :tags]
    )

    render json: {
      articles: @articles.as_json(include: [:author, :tags]),
      pagination: pagination_meta
    }
  rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
    render json: { error: "Invalid filter: #{e.message}" },
           status: :bad_request
  rescue BetterModel::Errors::Searchable::InvalidOrderError => e
    render json: { error: "Invalid sort: #{e.message}" },
           status: :bad_request
  rescue BetterModel::Errors::Searchable::InvalidPaginationError => e
    render json: { error: "Invalid pagination: #{e.message}" },
           status: :bad_request
  end

  private

  def build_predicates
    {}.tap do |p|
      p[:title_cont] = params[:q] if params[:q].present?
      p[:status_eq] = params[:status] if params[:status].present?
      p[:view_count_gteq] = params[:min_views] if params[:min_views].present?
    end
  end
end
```

## Introspection Methods

### 23. searchable_field?

**Cosa fa**: Check se un field è searchable (Predicable-configured).

**Quando usarlo**: Dynamic form validation, parameter whitelisting.

**Esempio**:
```ruby
class Article < ApplicationRecord
  predicates :title, :status, :view_count
  sort :title, :published_at
  searchable { per_page 25 }
end

Article.searchable_field?(:title)       # => true
Article.searchable_field?(:status)      # => true
Article.searchable_field?(:nonexistent) # => false

# Usage in controller
def search_params
  params.permit(*allowed_predicates).to_h
end

def allowed_predicates
  params.keys.select { |k| Article.searchable_field?(k.to_s.split('_')[0].to_sym) }
end
```

### 24. searchable_predicates_for

**Cosa fa**: Restituisce tutti i predicates disponibili per un field specifico.

**Quando usarlo**: Dynamic UIs, API documentation, validation.

**Esempio**:
```ruby
Article.searchable_predicates_for(:title)
# => [:title_eq, :title_not_eq, :title_cont, :title_i_cont,
#     :title_start, :title_end, :title_matches, :title_in,
#     :title_present, :title_blank, ...]

Article.searchable_predicates_for(:view_count)
# => [:view_count_eq, :view_count_not_eq, :view_count_lt,
#     :view_count_lteq, :view_count_gt, :view_count_gteq,
#     :view_count_between, :view_count_in, ...]

# Dynamic form builder
Article.searchable_fields.each do |field|
  predicates = Article.searchable_predicates_for(field)
  # Generate form inputs per predicate
end
```

### 25. searchable_sorts_for

**Cosa fa**: Restituisce sort scopes disponibili per un field.

**Quando usarlo**: Sort dropdowns, API docs, dynamic sort options.

**Esempio**:
```ruby
Article.searchable_sorts_for(:title)
# => [:sort_title_asc, :sort_title_desc,
#     :sort_title_asc_i, :sort_title_desc_i]

Article.searchable_sorts_for(:published_at)
# => [:sort_published_at_asc, :sort_published_at_desc,
#     :sort_published_at_newest, :sort_published_at_oldest,
#     :sort_published_at_asc_nulls_last, ...]

# Dynamic sort selector
<select name="sort">
  <% Article.searchable_sorts_for(:published_at).each do |sort| %>
    <option value="<%= sort %>"><%= sort.to_s.humanize %></option>
  <% end %>
</select>
```

### 26. search_metadata

**Cosa fa**: Restituisce comprehensive metadata su tutte le search options disponibili.

**Quando usarlo**: Auto-generate search forms, API documentation, client SDKs.

**Esempio**:
```ruby
metadata = Article.first.search_metadata

# Returns Hash:
{
  searchable_fields: [:title, :status, :view_count, :published_at],
  sortable_fields: [:title, :view_count, :published_at],
  available_predicates: {
    title: [:title_eq, :title_cont, :title_i_cont, ...],
    status: [:status_eq, :status_in, ...],
    view_count: [:view_count_gt, :view_count_between, ...]
  },
  available_sorts: {
    title: [:sort_title_asc, :sort_title_desc, ...],
    view_count: [:sort_view_count_asc, ...]
  },
  pagination: {
    per_page: 25,
    max_per_page: 100
  }
}

# Use for dynamic forms
metadata[:available_predicates].each do |field, predicates|
  # Generate search form fields
end
```

## Error Handling

**ℹ️ Version 3.0.0 Compatible**: Tutti gli error examples usano standard Ruby exception patterns con `e.message`.

### 27. InvalidPredicateError

**Cosa fa**: Raised quando usi un predicate scope non esistente.

**Quando usarlo**: Catch per validazione input e user-friendly errors.

**Esempio**:
```ruby
# Invalid predicate
Article.search({ nonexistent_predicate: "value" })
# ❌ Raises: BetterModel::Errors::Searchable::InvalidPredicateError
#   Invalid predicate scope: nonexistent_predicate
#   Available: title_eq, title_cont, status_eq, ...

# Handling
begin
  Article.search(params)
rescue BetterModel::Errors::Searchable::InvalidPredicateError => e
  Rails.logger.warn("Invalid search: #{e.message}")
  render json: { error: "Invalid filter" }, status: :bad_request
end
```

### 28. InvalidOrderError

**Cosa fa**: Raised quando usi un sort scope non esistente.

**Quando usarlo**: Validation di sort parameters da user input.

**Esempio**:
```ruby
# Invalid sort scope
Article.search({}, orders: [:nonexistent_sort])
# ❌ Raises: BetterModel::Errors::Searchable::InvalidOrderError
#   Invalid order scope: nonexistent_sort
#   Available: sort_title_asc, sort_view_count_desc, ...

# Handling con fallback
begin
  Article.search({}, orders: params[:orders])
rescue BetterModel::Errors::Searchable::InvalidOrderError => e
  # Fallback to default order
  Article.search({})
end
```

### 29. InvalidPaginationError

**Cosa fa**: Raised per invalid pagination parameters.

**Quando usarlo**: Validation di page/per_page from user input.

**Esempio**:
```ruby
# page < 1
Article.search({}, pagination: { page: 0 })
# ❌ Raises: InvalidPaginationError - page must be >= 1

# per_page < 1
Article.search({}, pagination: { page: 1, per_page: 0 })
# ❌ Raises: InvalidPaginationError - per_page must be >= 1

# Handling
begin
  Article.search({}, pagination: {
    page: params[:page],
    per_page: params[:per_page]
  })
rescue BetterModel::Errors::Searchable::InvalidPaginationError => e
  # Retry with defaults
  Article.search({}, pagination: { page: 1, per_page: 25 })
end
```

### 30. InvalidSecurityError

**Cosa fa**: Raised per security rule violations.

**Quando usarlo**: Multi-tenant enforcement, role-based access control.

**Esempio**:
```ruby
# Unknown security name
Article.search({}, security: :nonexistent)
# ❌ Raises: InvalidSecurityError
#   Unknown security: nonexistent
#   Available: status_required, tenant_scope

# Missing required predicate
Article.search({ title_cont: "Test" }, security: :status_required)
# ❌ Raises: InvalidSecurityError
#   Security :status_required requires: status_eq

# Handling
begin
  Document.search(params, security: :tenant_required)
rescue BetterModel::Errors::Searchable::InvalidSecurityError => e
  render json: { error: "Unauthorized" }, status: :forbidden
end
```

## Real-World Examples

### 31. Blog Search - Text + Filters

**Cosa fa**: Complete blog search con text search, filters, date ranges.

**Quando usarlo**: Content sites, blogs, news platforms.

**Esempio**:
```ruby
class Article < ApplicationRecord
  belongs_to :author
  belongs_to :category

  predicates :title, :content, :status, :view_count, :published_at, :category_id
  sort :title, :view_count, :published_at, :created_at

  searchable do
    per_page 25
    max_per_page 100
    default_order [:sort_published_at_desc, :sort_created_at_desc]
  end
end

# Controller
class ArticlesController < ApplicationController
  def index
    @articles = Article.search(
      build_predicates,
      pagination: { page: params[:page], per_page: 25 },
      orders: order_params,
      includes: [:author, :category]
    )
  end

  private

  def build_predicates
    {}.tap do |p|
      p[:title_i_cont] = params[:q] if params[:q].present?
      p[:status_eq] = params[:status] if params[:status].present?
      p[:category_id_eq] = params[:category] if params[:category].present?

      if params[:from_date].present?
        p[:published_at_gteq] = params[:from_date]
      end

      p[:view_count_gteq] = params[:min_views] if params[:min_views].present?
    end
  end

  def order_params
    case params[:sort]
    when "newest" then [:sort_published_at_desc]
    when "popular" then [:sort_view_count_desc]
    when "title" then [:sort_title_asc_i]
    else [:sort_published_at_desc]
    end
  end
end
```

### 32. E-commerce con OR Conditions

**Cosa fa**: Product search con OR logic per text search across fields.

**Quando usarlo**: E-commerce, catalogs, inventory search.

**Esempio**:
```ruby
class Product < ApplicationRecord
  belongs_to :category
  belongs_to :brand

  predicates :name, :sku, :price, :stock, :category_id, :brand_id, :status
  sort :name, :price, :created_at

  searchable do
    per_page 24
    max_per_page 96
    default_order [:sort_name_asc_i]
    security :active_only, [:status_eq]
  end
end

# Controller
def search
  @products = Product.search(
    build_predicates,
    pagination: { page: params[:page], per_page: 24 },
    orders: order_params,
    includes: [:category, :brand]
  )
end

def build_predicates
  predicates = { status_eq: "active" }

  # OR: name or SKU search
  if params[:q].present?
    predicates[:or] = [
      { name_i_cont: params[:q] },
      { sku_cont: params[:q] }
    ]
  end

  # Filters
  predicates[:category_id_in] = params[:category_ids] if params[:category_ids]
  predicates[:price_between] = [params[:min_price], params[:max_price]] if params[:min_price]

  predicates
end
```

### 33. Multi-Tenant con Security

**Cosa fa**: Document search con mandatory tenant scoping.

**Quando usarlo**: Multi-tenant SaaS apps con strict data isolation.

**Esempio**:
```ruby
class Document < ApplicationRecord
  belongs_to :tenant
  belongs_to :folder

  predicates :title, :content, :tenant_id, :folder_id, :status, :created_at
  sort :title, :created_at, :updated_at

  searchable do
    per_page 50
    max_per_page 200
    default_order [:sort_updated_at_desc]
    security :tenant_required, [:tenant_id_eq]
    max_predicates 15
  end
end

# Controller
class DocumentsController < ApplicationController
  before_action :authenticate_user!

  def index
    @documents = Document.search(
      build_predicates,
      pagination: pagination_params,
      security: :tenant_required,
      includes: [:folder]
    )
  rescue BetterModel::Errors::Searchable::InvalidSecurityError => e
    redirect_to root_path, alert: "Unauthorized"
  end

  private

  def build_predicates
    # CRITICAL: Always include tenant_id
    predicates = { tenant_id_eq: current_tenant.id }

    # Text search
    if params[:q].present?
      predicates[:or] = [
        { title_i_cont: params[:q] },
        { content_i_cont: params[:q] }
      ]
    end

    predicates[:folder_id_eq] = params[:folder_id] if params[:folder_id]
    predicates[:status_eq] = params[:status] if params[:status]

    predicates
  end
end
```

### 34. Job Board - Complex Criteria

**Cosa fa**: Job listing search con salary ranges, skills, location filters.

**Quando usarlo**: Job boards, recruitment platforms, classified ads.

**Esempio**:
```ruby
class JobListing < ApplicationRecord
  belongs_to :company
  belongs_to :location

  predicates :title, :description, :employment_type, :experience_level,
             :remote_ok, :salary_min, :salary_max, :posted_at
  sort :posted_at, :salary_max, :title

  searchable do
    per_page 20
    max_per_page 100
    default_order [:sort_posted_at_desc]
  end
end

# Search
JobListing.search({
  title_cont: "ruby developer",
  employment_type_eq: "full_time",
  remote_ok_eq: true,
  salary_min_gteq: 80_000,
  salary_max_lteq: 150_000,
  posted_at_gteq: 7.days.ago
}, orders: [:sort_posted_at_desc])
```

### 35. Real Estate - Property Search

**Cosa fa**: Property search con price ranges, bedrooms, amenities.

**Quando usarlo**: Real estate platforms, rental sites, property listings.

**Esempio**:
```ruby
class Property < ApplicationRecord
  belongs_to :neighborhood

  predicates :address, :property_type, :listing_type, :price,
             :bedrooms, :bathrooms, :square_feet, :year_built
  sort :price, :bedrooms, :square_feet

  searchable do
    per_page 24
    max_per_page 100
    default_order [:sort_price_asc]
  end
end

# Search
Property.search({
  property_type_eq: "house",
  listing_type_eq: "sale",
  price_between: [400_000, 600_000],
  bedrooms_gteq: 3,
  bathrooms_gteq: 2,
  square_feet_gteq: 2000,
  year_built_gteq: 2000
}, orders: [:sort_price_asc])
```

## Best Practices

### ✅ Do

1. **Strong Parameters**: Sempre whitelist con permit
2. **DoS Protection**: Sempre set max_per_page, max_page, max_predicates
3. **Security Rules**: Usa security enforcement per multi-tenant
4. **Default Order**: Configura ordering predicibile
5. **Eager Loading**: Usa includes:/preload: per prevent N+1
6. **Error Handling**: Catch specific error classes
7. **Validation**: Map user-friendly sort names to scopes
8. **Introspection**: Use metadata per dynamic UIs

### ❌ Don't

1. **Non usare params unsafe**: Mai `params.to_unsafe_h`
2. **Non skip security**: Multi-tenant apps richiedono security enforcement
3. **Non ignorare limits**: Missing max_per_page è DoS risk
4. **Non trust user input**: Sempre validate sort/predicate names
5. **Non dimenticare eager load**: N+1 queries sono common pitfall
6. **Non generic errors**: Catch specific exceptions per better UX
7. **Non direct parameter uso**: Validate/map sort names
8. **Non dimenticare indexes**: Add indexes per frequently filtered columns

## Thread Safety e Performance

**Thread Safety**:
- Configuration frozen at class load time
- No mutable shared state
- Each search() call operates independently
- Safe for concurrent requests

**Performance**:
- Single optimized SQL query
- Use indexes for filtered columns
- Eager loading prevents N+1
- Pagination limits result sets
- DoS protection prevents abuse

## Key Takeaways

1. **Orchestrator**: Unifica Predicable + Sortable + Pagination
2. **Single Method API**: `search()` per tutto
3. **Security Built-in**: Enforce required predicates
4. **DoS Protection**: max_per_page, max_page, max_predicates
5. **OR Conditions**: Special `:or` key per boolean logic
6. **Eager Loading**: includes/preload/eager_load parameters
7. **Strong Parameters**: Sempre sanitize user input
8. **Error Handling**: 4 specific error classes
9. **Introspection**: search_metadata per dynamic UIs
10. **Chainable**: Returns ActiveRecord::Relation
11. **Thread-Safe**: Frozen config, no shared state
12. **Performance**: Single SQL query, use indexes
13. **Multi-Tenant**: Security rules obbligatori
14. **Validation**: All parameters validated
15. **Default Order**: Configure sensible defaults

---

**Compatibile con**: Rails 8.0+, Ruby 3.0+
**Thread-safe**: Sì
**Opt-in**: Sì (richiede Predicable + Sortable + `searchable do...end`)
