# Multi-stage Dockerfile for BetterModel gem development
# Base image: Ruby 3.3 on Alpine Linux for lightweight containers

FROM ruby:3.3-alpine AS base

# Install system dependencies required for gem compilation
# - build-base: gcc, make, and other build tools
# - sqlite-dev: SQLite development headers
# - git: version control (needed by some gems)
# - tzdata: timezone data for Rails
RUN apk add --no-cache \
    build-base \
    sqlite-dev \
    git \
    tzdata

# Set working directory
WORKDIR /app

# Development stage
FROM base AS development

# Copy Gemfile and Gemfile.lock for dependency installation
# This is done separately to leverage Docker layer caching
COPY Gemfile Gemfile.lock better_model.gemspec ./
COPY lib/better_model/version.rb ./lib/better_model/

# Install gem dependencies
RUN bundle config set --local without 'production' && \
    bundle install --jobs 4 --retry 3

# Copy the rest of the application
COPY . .

# Create a non-root user for security
RUN addgroup -g 1000 better && \
    adduser -D -u 1000 -G better better && \
    chown -R better:better /app

# Switch to non-root user
USER better

# Default command: open a bash shell
CMD ["/bin/sh"]

# Test stage - for running tests in CI
FROM development AS test

# Switch back to root to install test dependencies if needed
USER root

# Ensure test database is ready
RUN bundle exec rake db:test:prepare || true

# Switch back to non-root user
USER better

# Default command for test stage
CMD ["bundle", "exec", "rake", "test"]
