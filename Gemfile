source "https://rubygems.org"

# Specify your gem's dependencies in better_model.gemspec.
gemspec

gem "puma"

gem "sqlite3"

# Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
gem "rubocop-rails-omakase", require: false

# Dependency vulnerability scanning [https://github.com/rubysec/bundler-audit]
gem "bundler-audit", require: false

# Code coverage [https://github.com/simplecov-ruby/simplecov]
gem "simplecov", require: false
gem "simplecov-cobertura", require: false

# Start debugger with binding.b [https://github.com/ruby/debug]
# gem "debug", ">= 1.0.0"

# Testing with RSpec
group :development, :test do
  gem "rspec-rails", "~> 8.0"
  gem "factory_bot_rails", "~> 6.4"
  gem "shoulda-matchers", "~> 6.0"
  gem "database_cleaner-active_record", "~> 2.1"
  gem "ammeter", "~> 1.1"
end
