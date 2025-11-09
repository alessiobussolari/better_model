# BetterModel Error System - Developer Guidelines

This document provides comprehensive guidelines for working with the BetterModel error system. Follow these conventions when creating new errors or modifying existing ones.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Error Hierarchy](#error-hierarchy)
3. [Directory Structure](#directory-structure)
4. [Sentry Integration System](#sentry-integration-system)
5. [Creating New Errors](#creating-new-errors)
6. [Error Attributes Pattern](#error-attributes-pattern)
7. [Initialization Pattern](#initialization-pattern)
8. [Message Building Pattern](#message-building-pattern)
9. [YARD Documentation](#yard-documentation)
10. [Error Types Catalog](#error-types-catalog)
11. [Best Practices](#best-practices)

---

## Architecture Overview

The BetterModel error system is designed with three key principles:

1. **Hierarchical Organization**: Three-tier inheritance (Root → Module → Specific)
2. **Sentry-First Design**: All errors include structured monitoring data
3. **Consistency**: Standardized patterns across all modules

### Key Components

- **Root Error Class**: `BetterModel::Errors::BetterModelError`
- **Module Base Classes**: One per module (e.g., `ArchivableError`, `SearchableError`)
- **Specific Errors**: Concrete error classes for specific failure scenarios
- **SentryCompatible Concern**: Shared helper methods for monitoring integration

---

## Error Hierarchy

### Three-Tier Structure

```
StandardError / ArgumentError
    └── BetterModelError (root)
        └── ModuleError (base for each module)
            └── SpecificErrors (concrete errors)
```

### Root Class: BetterModelError

**File**: `lib/better_model/errors/better_model_error.rb`

```ruby
module BetterModel
  module Errors
    class BetterModelError < StandardError
      attr_reader :context, :tags, :extra

      def initialize(message = nil)
        @context ||= {}
        @tags ||= {}
        @extra ||= {}
        super(message)
      end
    end
  end
end
```

**Attributes**:
- `context`: High-level structured metadata (model_class, etc.)
- `tags`: Filterable metadata for Sentry grouping/searching
- `extra`: Detailed debug data with all error-specific parameters

### Module Base Classes

Each BetterModel module has its own base error class:

```ruby
module BetterModel
  module Errors
    module Archivable
      class ArchivableError < BetterModelError
      end
    end
  end
end
```

**Pattern**:
- Inherits from `BetterModelError`
- Minimal implementation (just the inheritance)
- Acts as namespace for module-specific errors
- Located in `lib/better_model/errors/{module_name}/{module_name}_error.rb`

### Exception: ConfigurationError

`ConfigurationError` classes inherit from `ArgumentError` instead of their module base:

```ruby
class ConfigurationError < ArgumentError
  include BetterModel::Errors::Concerns::SentryCompatible

  # CRITICAL: Must explicitly define these attributes
  attr_reader :context, :tags, :extra
  attr_reader :reason, :model_class, :expected, :provided
end
```

**Why?** Configuration errors are argument validation failures, so they inherit from `ArgumentError` for semantic correctness.

---

## Directory Structure

```
lib/better_model/errors/
├── better_model_error.rb              # Root error class
├── concerns/
│   └── sentry_compatible.rb           # Shared concern for Sentry integration
└── {module_name}/                     # One directory per module
    ├── {module_name}_error.rb         # Module base error
    ├── configuration_error.rb         # Configuration validation errors
    ├── not_enabled_error.rb           # Module not enabled errors (optional)
    └── {specific}_error.rb            # Module-specific errors
```

### Naming Conventions

- **Files**: Snake case with `_error.rb` suffix
- **Classes**: CamelCase with `Error` suffix
- **Namespaces**: `BetterModel::Errors::{Module}::{Error}`

**Example**:
- File: `lib/better_model/errors/searchable/invalid_predicate_error.rb`
- Class: `BetterModel::Errors::Searchable::InvalidPredicateError`

---

## Sentry Integration System

### SentryCompatible Concern

**File**: `lib/better_model/errors/concerns/sentry_compatible.rb`

All concrete error classes must include this concern:

```ruby
class MyError < ModuleError
  include BetterModel::Errors::Concerns::SentryCompatible
end
```

### Data Structures

#### 1. Tags (Filterable Metadata)

**Purpose**: For grouping and searching errors in Sentry

**Structure**:
```ruby
{
  error_category: "string",  # Required: type of error
  module: "string",          # Auto-extracted: module name
  # ... custom tags
}
```

**Characteristics**:
- All values MUST be strings (Sentry requirement)
- `module` is automatically extracted from class namespace
- Custom tags are normalized to strings

**Common Tag Keys**:
- `error_category`: Type of error (required)
- `module`: Module name (auto-added)
- `event`: For state transitions
- `from_state`, `to_state`: For transitions
- `predicate`: For predicate errors
- `policy`: For security errors
- `parameter`: For pagination errors

#### 2. Context (High-Level Metadata)

**Purpose**: Structured contextual information

**Structure**:
```ruby
{
  model_class: "ClassName",     # Optional but recommended
  module_name: "ModuleName",    # Optional
  current_state: :state_name,   # Optional, for stateful errors
  # ... other high-level context
}
```

**Characteristics**:
- Compact (nil values removed)
- Contains model_class name if provided
- High-level contextual data only

#### 3. Extra (Detailed Debug Data)

**Purpose**: All error-specific detailed information

**Structure**:
```ruby
{
  # All error attributes go here
  predicate_scope: :title_xxx,
  value: "Rails",
  available_predicates: [...],
  # etc.
}
```

**Characteristics**:
- Compact (nil values removed)
- Contains all detailed error-specific data
- Can include complex objects (arrays, hashes)

### Helper Methods

#### `build_tags(error_category:, **custom_tags)`

Builds the tags hash with automatic module extraction.

```ruby
@tags = build_tags(
  error_category: "invalid_predicate",
  predicate: predicate_scope
)
# => {error_category: "invalid_predicate", module: "searchable", predicate: "title_xxx"}
```

**Parameters**:
- `error_category`: (required) Symbol or String
- `**custom_tags`: Additional tags to include

**Returns**: Hash with merged tags (all values as strings)

#### `build_context(model_class: nil, **custom_context)`

Builds the context hash.

```ruby
@context = build_context(
  model_class: model_class,
  current_state: current_state
)
# => {model_class: "Article", current_state: :draft}
```

**Parameters**:
- `model_class`: (optional) Class object
- `**custom_context`: Additional context to include

**Returns**: Compacted hash (nil values removed)

#### `build_extra(**data)`

Builds the extra hash.

```ruby
@extra = build_extra(
  predicate_scope: predicate_scope,
  value: value,
  available_predicates: available_predicates
)
```

**Parameters**:
- `**data`: All error-specific data

**Returns**: Compacted hash (nil values removed)

---

## Creating New Errors

### Step-by-Step Guide

#### 1. Create the Error File

Create file in the appropriate module directory:

```
lib/better_model/errors/{module_name}/{error_name}_error.rb
```

#### 2. Define the Error Class

```ruby
# frozen_string_literal: true

require_relative "{module_name}_error"
require_relative "../concerns/sentry_compatible"

module BetterModel
  module Errors
    module {ModuleName}
      # Brief description of when this error is raised.
      #
      # @example
      #   raise MyError.new(
      #     param1: value1,
      #     param2: value2,
      #     model_class: Article
      #   )
      class MyError < {ModuleName}Error
        include BetterModel::Errors::Concerns::SentryCompatible

        attr_reader :param1, :param2, :model_class

        # Initialize a new MyError.
        #
        # @param param1 [Type] Description of param1
        # @param param2 [Type] Description of param2
        # @param model_class [Class, nil] Model class (optional)
        def initialize(param1:, param2:, model_class: nil)
          @param1 = param1
          @param2 = param2
          @model_class = model_class

          @tags = build_tags(
            error_category: "my_error_category",
            custom_tag: param1
          )

          @context = build_context(
            model_class: model_class
          )

          @extra = build_extra(
            param1: param1,
            param2: param2
          )

          super(build_message)
        end

        private

        def build_message
          "Error message describing the problem"
        end
      end
    end
  end
end
```

#### 3. Special Case: ConfigurationError

When creating a `ConfigurationError`:

```ruby
class ConfigurationError < ArgumentError
  include BetterModel::Errors::Concerns::SentryCompatible

  # CRITICAL: Must explicitly define these
  attr_reader :context, :tags, :extra
  attr_reader :reason, :model_class, :expected, :provided

  # @param reason [String] Description of configuration problem
  # @param model_class [Class, nil] Model class (optional)
  # @param expected [Object, nil] Expected value/type (optional)
  # @param provided [Object, nil] Provided value/type (optional)
  def initialize(reason:, model_class: nil, expected: nil, provided: nil)
    # ... same pattern as above
  end
end
```

---

## Error Attributes Pattern

### Required Attributes (All Errors)

All errors inherit these from `BetterModelError`:

```ruby
attr_reader :context  # Hash: high-level metadata
attr_reader :tags     # Hash: filterable tags
attr_reader :extra    # Hash: detailed debug data
```

### Common Optional Attributes

```ruby
attr_reader :model_class      # Class: where error occurred
attr_reader :module_name      # String: module name
attr_reader :method_called    # String/Symbol: method that was called
```

### Error-Specific Attributes

Define attributes specific to your error:

```ruby
attr_reader :predicate_scope      # Symbol
attr_reader :available_predicates # Array<Symbol>
attr_reader :value                # Object
```

### Attribute Guidelines

1. **Always use `attr_reader`**: Errors should be immutable after creation
2. **Document with YARD**: Add `@param` tags in `initialize`
3. **Use descriptive names**: Clear and self-documenting
4. **Include `model_class`**: Almost always optional, but recommended
5. **Provide defaults**: Use `nil` for optional parameters

---

## Initialization Pattern

### Standard Pattern (BetterModelError Subclasses)

```ruby
def initialize(param1:, param2: nil, model_class: nil)
  # 1. Store attributes
  @param1 = param1
  @param2 = param2
  @model_class = model_class

  # 2. Build tags (required: error_category)
  @tags = build_tags(
    error_category: "category_name",
    custom_tag: param1
  )

  # 3. Build context
  @context = build_context(
    model_class: model_class,
    custom_field: value
  )

  # 4. Build extra (all details)
  @extra = build_extra(
    param1: param1,
    param2: param2
  )

  # 5. Call super with message
  super(build_message)
end
```

### ArgumentError Subclass Pattern (ConfigurationError)

```ruby
class ConfigurationError < ArgumentError
  include BetterModel::Errors::Concerns::SentryCompatible

  # MUST explicitly declare these!
  attr_reader :context, :tags, :extra
  attr_reader :reason, :model_class, :expected, :provided

  def initialize(reason:, model_class: nil, expected: nil, provided: nil)
    # Same pattern as above
  end
end
```

**Critical Difference**: Must explicitly declare `attr_reader :context, :tags, :extra` because not inherited from `BetterModelError`.

### Parameter Conventions

- **Required parameters**: No default value
  ```ruby
  def initialize(event:, from_state:, to_state:)
  ```

- **Optional parameters**: Default to `nil`
  ```ruby
  def initialize(event:, model_class: nil, metadata: nil)
  ```

- **Common optional parameter**: `model_class` (for tracking which model raised the error)

### Initialization Order

Always follow this order:

1. Store all parameters in instance variables
2. Build `@tags` (with `error_category`)
3. Build `@context`
4. Build `@extra`
5. Call `super(build_message)`

---

## Message Building Pattern

### Private Method

All errors implement a private `build_message` method:

```ruby
private

def build_message
  # Build and return error message string
end
```

### Common Patterns

#### 1. Simple Descriptive Message

```ruby
def build_message
  "Invalid state: #{state.inspect}"
end
```

#### 2. Conditional Additions

```ruby
def build_message
  msg = "Record is already archived"
  msg += " (archived at: #{archived_at})" if archived_at
  msg
end
```

#### 3. List Available Options

```ruby
def build_message
  msg = "Invalid predicate scope: #{predicate_scope.inspect}."
  if available_predicates.any?
    msg += " Available predicable scopes: #{available_predicates.join(', ')}"
  end
  msg
end
```

#### 4. Custom Reason with Fallback

```ruby
def build_message
  return reason if reason

  # Build default message
  msg = "Invalid pagination parameter '#{parameter_name}'"
  msg += ": #{value}" if value
  msg
end
```

#### 5. Include Expected/Provided

```ruby
def build_message
  msg = reason
  msg += " (expected: #{expected.inspect})" if expected
  msg += " (provided: #{provided.inspect})" if provided
  msg
end
```

#### 6. Complex Messages with Collections

```ruby
def build_message
  "Validation failed for transition #{event.inspect}: #{errors_object.full_messages.join(', ')}"
end
```

### Message Best Practices

1. **Use `inspect` for symbols/objects**: Ensures clear representation
2. **Join arrays with `', '`**: For readability
3. **Conditional appending**: Add optional details only when present
4. **Be concise but informative**: Include helpful debugging context
5. **Include available options**: Help users know what's valid
6. **Use consistent formatting**: Follow existing error message patterns

---

## YARD Documentation

### Class-Level Documentation

```ruby
# Brief description of when this error is raised.
#
# Longer description with more details about the error scenario,
# when it occurs, and what it means.
#
# @example Basic usage
#   raise MyError.new(
#     param1: value1,
#     param2: value2,
#     model_class: Article
#   )
#
# @example Accessing error data
#   rescue MyError => e
#     e.param1      # => value1
#     e.param2      # => value2
#     e.model_class # => Article
#
#     # Sentry-compatible data
#     e.tags    # => {error_category: 'my_error', module: 'module_name'}
#     e.context # => {model_class: 'Article'}
#     e.extra   # => {param1: value1, param2: value2}
class MyError < ModuleError
```

### Initialize Method Documentation

```ruby
# Initialize a new MyError.
#
# @param param1 [Type] Description of parameter
# @param param2 [Type, OtherType] Description (multiple types allowed)
# @param optional_param [Type, nil] Description (optional)
# @param model_class [Class, nil] Model class (optional)
def initialize(param1:, param2:, optional_param: nil, model_class: nil)
```

### Documentation Requirements

1. **Class description**: What the error represents
2. **@example blocks**: Show how to raise and rescue the error
3. **@param tags**: For EVERY parameter in initialize
4. **Type specifications**: Use square brackets `[Type]`
5. **Optional indicators**: Use `[Type, nil]` for optional params
6. **Sentry data example**: Show tags/context/extra structure

### Type Specifications

```ruby
@param name [String]                    # Single type
@param count [Integer, nil]             # Optional
@param value [String, Symbol]           # Multiple types
@param data [Hash, Array]               # Complex types
@param callback [Proc, nil]             # Callable
@param model_class [Class, nil]         # Class object
@param states [Array<Symbol>]           # Typed array
@param errors [ActiveModel::Errors]     # Rails type
```

---

## Error Types Catalog

### Common Errors (Multiple Modules)

#### ConfigurationError

**Modules**: All 10 modules
**Inheritance**: `ArgumentError` (not BetterModelError!)
**Attributes**: `reason`, `model_class`, `expected`, `provided`
**Use Case**: Configuration validation failures

**Standard Implementation**:
```ruby
class ConfigurationError < ArgumentError
  include BetterModel::Errors::Concerns::SentryCompatible

  attr_reader :context, :tags, :extra
  attr_reader :reason, :model_class, :expected, :provided

  def initialize(reason:, model_class: nil, expected: nil, provided: nil)
    # Standard pattern
  end
end
```

#### NotEnabledError

**Modules**: Archivable, Traceable, Validatable, Stateable
**Inheritance**: Module-specific error (e.g., `ArchivableError`)
**Attributes**: `module_name`, `method_called`, `model_class`
**Use Case**: Module methods called before module is enabled

### Module-Specific Errors

#### Archivable (5 errors)
- `ArchivableError` (base)
- `ConfigurationError`
- `NotEnabledError`
- `AlreadyArchivedError` - Attempting to archive already-archived record
- `NotArchivedError` - Attempting operation requiring archived record

#### Searchable (6 errors)
- `SearchableError` (base)
- `ConfigurationError`
- `InvalidPredicateError` - Invalid search predicate used
- `InvalidOrderError` - Invalid sort/order scope
- `InvalidPaginationError` - Invalid pagination parameters
- `InvalidSecurityError` - Security policy violation

#### Stateable (7 errors)
- `StateableError` (base)
- `ConfigurationError`
- `NotEnabledError`
- `InvalidTransitionError` - Invalid state machine transition
- `CheckFailedError` - Transition check/guard failed
- `ValidationFailedError` - ActiveModel validation failed during transition
- `InvalidStateError` - Invalid state referenced

#### Other Modules (2-3 errors each)
**Permissible, Predicable, Sortable, Statusable, Taggable, Traceable, Validatable**:
- `{Module}Error` (base)
- `ConfigurationError`
- Some have `NotEnabledError`

---

## Best Practices

### 1. Inheritance

✅ **DO**: Inherit from module-specific base error
```ruby
class MyError < SearchableError
```

✅ **DO**: Use `ArgumentError` for ConfigurationError
```ruby
class ConfigurationError < ArgumentError
```

❌ **DON'T**: Inherit directly from StandardError
```ruby
class MyError < StandardError  # Wrong!
```

### 2. SentryCompatible Concern

✅ **DO**: Always include the concern
```ruby
class MyError < ModuleError
  include BetterModel::Errors::Concerns::SentryCompatible
end
```

❌ **DON'T**: Skip the concern
```ruby
class MyError < ModuleError
  # Missing include!
end
```

### 3. Attributes

✅ **DO**: Declare all attributes with attr_reader
```ruby
attr_reader :param1, :param2, :model_class
```

✅ **DO**: Explicitly declare context/tags/extra for ArgumentError subclasses
```ruby
class ConfigurationError < ArgumentError
  attr_reader :context, :tags, :extra  # Required!
end
```

❌ **DON'T**: Use attr_accessor (errors should be immutable)
```ruby
attr_accessor :param1  # Wrong!
```

### 4. Initialization

✅ **DO**: Follow the standard order
```ruby
def initialize(param:, model_class: nil)
  @param = param
  @model_class = model_class
  @tags = build_tags(...)
  @context = build_context(...)
  @extra = build_extra(...)
  super(build_message)
end
```

✅ **DO**: Always provide error_category in tags
```ruby
@tags = build_tags(error_category: "my_category")
```

❌ **DON'T**: Call super before building data structures
```ruby
def initialize(param:)
  super(build_message)  # Wrong! Do this last
  @tags = build_tags(...)
end
```

### 5. Error Messages

✅ **DO**: Use inspect for symbols and objects
```ruby
"Invalid state: #{state.inspect}"
```

✅ **DO**: Provide helpful context
```ruby
msg += " Available states: #{available_states.join(', ')}"
```

❌ **DON'T**: Expose sensitive data in messages
```ruby
"Password validation failed: #{password}"  # Wrong!
```

### 6. Documentation

✅ **DO**: Document all parameters with YARD
```ruby
# @param event [Symbol] The transition event
# @param model_class [Class, nil] Model class (optional)
```

✅ **DO**: Provide usage examples
```ruby
# @example
#   raise MyError.new(param: value)
```

❌ **DON'T**: Skip documentation
```ruby
def initialize(param:)  # Missing @param tags!
```

### 7. File Organization

✅ **DO**: Place errors in correct module directory
```
lib/better_model/errors/searchable/invalid_predicate_error.rb
```

✅ **DO**: Follow naming conventions
- File: `invalid_predicate_error.rb` (snake_case)
- Class: `InvalidPredicateError` (CamelCase)

❌ **DON'T**: Mix error locations
```
lib/better_model/searchable/errors/  # Wrong location!
```

### 8. Testing

✅ **DO**: Test error attributes are set correctly
```ruby
error = MyError.new(param: value)
expect(error.param).to eq(value)
expect(error.tags[:error_category]).to eq("my_category")
```

✅ **DO**: Test error messages
```ruby
expect(error.message).to include("expected context")
```

✅ **DO**: Test Sentry data structures
```ruby
expect(error.context).to include(model_class: "Article")
expect(error.tags).to include(module: "searchable")
expect(error.extra).to have_key(:param)
```

---

## Quick Reference Checklist

When creating a new error, ensure:

- [ ] File in correct directory: `lib/better_model/errors/{module}/`
- [ ] Correct inheritance: Module base error or ArgumentError
- [ ] Include `SentryCompatible` concern
- [ ] Declare all attributes with `attr_reader`
- [ ] For ArgumentError: explicitly declare `context`, `tags`, `extra`
- [ ] YARD documentation on class and initialize
- [ ] `@param` tags for all parameters
- [ ] Initialize follows standard order
- [ ] `build_tags` includes `error_category`
- [ ] `build_message` private method
- [ ] Usage examples in documentation
- [ ] Test coverage for attributes and messages

---

## Examples

### Complete Example: Simple Error

```ruby
# frozen_string_literal: true

require_relative "module_error"
require_relative "../concerns/sentry_compatible"

module BetterModel
  module Errors
    module MyModule
      # Raised when a record is in an invalid state for the operation.
      #
      # @example
      #   raise InvalidStateError.new(
      #     state: :unknown,
      #     available_states: [:draft, :published],
      #     model_class: Article
      #   )
      class InvalidStateError < MyModuleError
        include BetterModel::Errors::Concerns::SentryCompatible

        attr_reader :state, :available_states, :model_class

        # Initialize a new InvalidStateError.
        #
        # @param state [Symbol] The invalid state that was referenced
        # @param available_states [Array<Symbol>] List of valid states
        # @param model_class [Class, nil] Model class (optional)
        def initialize(state:, available_states: [], model_class: nil)
          @state = state
          @available_states = available_states
          @model_class = model_class

          @tags = build_tags(error_category: "invalid_state")

          @context = build_context(model_class: model_class)

          @extra = build_extra(
            state: state,
            available_states: available_states
          )

          super(build_message)
        end

        private

        def build_message
          msg = "Invalid state: #{state.inspect}"
          if available_states.any?
            msg += ". Available states: #{available_states.join(', ')}"
          end
          msg
        end
      end
    end
  end
end
```

### Complete Example: ConfigurationError

```ruby
# frozen_string_literal: true

require_relative "../concerns/sentry_compatible"

module BetterModel
  module Errors
    module MyModule
      # Raised when MyModule configuration is invalid.
      #
      # @example
      #   raise ConfigurationError.new(
      #     reason: "Invalid field type",
      #     model_class: Article,
      #     expected: Symbol,
      #     provided: String
      #   )
      class ConfigurationError < ArgumentError
        include BetterModel::Errors::Concerns::SentryCompatible

        attr_reader :context, :tags, :extra
        attr_reader :reason, :model_class, :expected, :provided

        # Initialize a new ConfigurationError.
        #
        # @param reason [String] Description of configuration problem
        # @param model_class [Class, nil] Model class (optional)
        # @param expected [Object, nil] Expected value/type (optional)
        # @param provided [Object, nil] Provided value/type (optional)
        def initialize(reason:, model_class: nil, expected: nil, provided: nil)
          @reason = reason
          @model_class = model_class
          @expected = expected
          @provided = provided

          @tags = build_tags(error_category: "configuration")

          @context = build_context(model_class: model_class)

          @extra = build_extra(
            reason: reason,
            expected: expected,
            provided: provided
          )

          super(build_message)
        end

        private

        def build_message
          msg = reason
          msg += " (expected: #{expected.inspect})" if expected
          msg += " (provided: #{provided.inspect})" if provided
          msg
        end
      end
    end
  end
end
```

---

## Conclusion

Following these guidelines ensures:

- **Consistency**: All errors follow the same patterns
- **Observability**: Comprehensive Sentry integration
- **Maintainability**: Clear structure and documentation
- **Developer Experience**: Easy to understand and extend

When in doubt, refer to existing errors in `lib/better_model/errors/` as examples.
