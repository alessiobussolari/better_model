# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BetterModel is a Rails engine gem (Rails 8.1+) that extends ActiveRecord model functionality. The gem is currently at version 1.3.0 and follows the standard Rails engine architecture.

## Architecture

### Gem Structure

- **lib/better_model.rb**: Main entry point that loads version and railtie
- **lib/better_model/railtie.rb**: Rails integration via Railtie (currently minimal)
- **lib/better_model/version.rb**: Version constant (1.3.0)
- **test/dummy/**: Rails application for testing the engine in isolation

### Rails Engine Pattern

This gem follows the Rails engine pattern where:
- The engine integrates with Rails applications via the Railtie
- The dummy app in test/dummy/ provides a sandbox Rails environment for testing
- The engine's lib/ directory contains the core functionality that will be loaded into host Rails apps

## Development Commands

### Testing

The gemspec currently has invalid placeholder URLs that prevent bundle commands from working. Before running tests, the gemspec metadata URLs need to be fixed (homepage, homepage_uri, source_code_uri, changelog_uri, allowed_push_host).

Once fixed, run tests with:
```bash
bundle exec rake test
```

To run a specific test file:
```bash
bundle exec ruby -Itest test/better_model_test.rb
```

### Code Style

The project uses rubocop-rails-omakase for Ruby styling:
```bash
bundle exec rubocop
```

Auto-fix style issues:
```bash
bundle exec rubocop -a
```

### Dependencies

Install dependencies:
```bash
bundle install
```

## Important Notes

- The gemspec (better_model.gemspec:8-19) contains TODO placeholders that must be replaced with actual values before the gem can be properly bundled or published
- Test fixtures are loaded from test/fixtures/ if present
- The dummy app uses SQLite3 for testing
