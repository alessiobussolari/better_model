# frozen_string_literal: true

FactoryBot.define do
  factory :author do
    name { "Test Author" }
    sequence(:email) { |n| "author#{n}@example.com" }
  end
end
