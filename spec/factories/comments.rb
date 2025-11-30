# frozen_string_literal: true

FactoryBot.define do
  factory :comment do
    association :article
    body { "Test comment body" }
    author_name { "Commenter" }
  end
end
