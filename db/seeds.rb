Category.insert_all(
  %w[Equipment Furniture Books Documents Other].map { |name| { name: name, created_at: Time.current, updated_at: Time.current } },
  unique_by: :index_categories_on_name
)
