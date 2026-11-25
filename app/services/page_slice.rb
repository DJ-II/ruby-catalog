class PageSlice
  attr_reader :page, :per_page, :records

  def initialize(scope, page:, per_page: 25)
    @page = Integer(page, exception: false).to_i.clamp(1, 10_000)
    @per_page = per_page
    rows = scope.limit(per_page + 1).offset((@page - 1) * per_page).to_a
    @has_next = rows.length > per_page
    @records = rows.first(per_page)
  end

  def next?
    @has_next
  end

  def previous?
    page > 1
  end
end
