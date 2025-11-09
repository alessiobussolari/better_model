# frozen_string_literal: true

require_relative "repositable/base_repository"

module BetterModel
  # Repositable provides the Repository Pattern infrastructure for BetterModel.
  #
  # Unlike other BetterModel concerns, Repositable is not included directly in models.
  # Instead, it provides a BaseRepository class that you can inherit from to create
  # repository classes for your models.
  #
  # @example Creating a repository
  #   class ArticleRepository < BetterModel::Repositable::BaseRepository
  #     def model_class = Article
  #
  #     def published
  #       search({ status_eq: "published" })
  #     end
  #   end
  #
  # @example Using a repository
  #   repo = ArticleRepository.new
  #   articles = repo.published
  #   article = repo.find(1)
  #
  # @see BetterModel::Repositable::BaseRepository
  #
  module Repositable
    # Version of the Repositable module
    VERSION = "1.0.0"
  end
end
