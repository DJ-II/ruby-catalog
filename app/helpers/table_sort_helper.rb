module TableSortHelper
  def sortable_heading(label, key)
    active = @sort == key
    direction = active && @direction == 'asc' ? 'desc' : 'asc'
    marker = active ? (@direction == 'asc' ? '↑' : '↓') : '↕'
    link_to url_for(request.query_parameters.merge('sort' => key, 'direction' => direction).except('page')), class: 'table-sort-link' do
      safe_join([label, content_tag(:span, '', class: 'sort-marker', data: { marker: marker }, aria: { hidden: true })])
    end
  end

  def table_sort_aria(key)
    @sort == key ? (@direction == 'asc' ? 'ascending' : 'descending') : 'none'
  end
end
