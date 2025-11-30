# frozen_string_literal: true

FactoryBot.define do
  factory :article do
    title { "Test Article" }
    content { "Test content for the article" }
    status { "draft" }
    view_count { 0 }

    trait :published do
      status { "published" }
      published_at { Time.current }
    end

    trait :scheduled do
      scheduled_at { 1.day.from_now }
    end

    trait :expired do
      status { "published" }
      published_at { 1.week.ago }
      expires_at { 1.day.ago }
    end

    trait :featured do
      featured { true }
    end

    trait :popular do
      view_count { 100 }
    end

    trait :with_author do
      association :author
    end

    trait :with_tags do
      tags { %w[ruby rails testing] }
    end
  end
end
