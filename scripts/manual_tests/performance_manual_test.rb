  # frozen_string_literal: true

  # TEST PERFORMANCE
  # ============================================================================

  section("PERFORMANCE - Test with Larger Dataset")

  puts "  Creazione di 100 articoli addizionali per test performance..."

  100.times do |i|
    Article.create!(
      title: "Perf Article #{i}",
      content: "Performance test content",
      status: [ "draft", "published" ].sample,
      view_count: rand(0..300),
      published_at: [ nil, rand(30).days.ago ].sample,
      featured: [ true, false ].sample
    )
  end

  total_articles = Article.count
  puts "  Totale articoli: #{total_articles}"

  test("search performs well with #{total_articles} records") do
    start_time = Time.now
    result = Article.search(
      { status_eq: "published", view_count_gteq: 50 },
      orders: [ :sort_view_count_desc ],
      pagination: { page: 1, per_page: 25 }
    )
    result.to_a # Force query execution
    elapsed = Time.now - start_time
    elapsed < 1.0 # Should complete in less than 1 second
  end

  test("complex search with OR performs well") do
    start_time = Time.now
    result = Article.search(
      {
        or: [
              { view_count_gt: 100 },
              { featured_eq: true }
            ],
        status_eq: "published"
      },
      orders: [ :sort_published_at_desc ]
    )
    result.to_a
    elapsed = Time.now - start_time
    elapsed < 1.0
  end
