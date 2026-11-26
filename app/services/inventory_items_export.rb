require 'csv'

class InventoryItemsExport
  BATCH_SIZE = 300

  def initialize(inventory)
    @inventory = inventory
    @fields = inventory.inventory_fields.select(&:active?).sort_by(&:position)
  end

  def headers
    [I18n.t('exports.columns.custom_id'), *@fields.map(&:title), I18n.t('exports.columns.creator'), I18n.t('exports.columns.created_at')]
  end

  def to_csv
    CSV.generate(encoding: 'UTF-8', force_quotes: true) do |csv|
      csv << headers.map { |value| escape_spreadsheet_formula(value) }
      each_item do |item|
        csv << values_for(item).map { |value| value.is_a?(String) ? escape_spreadsheet_formula(value) : (value.is_a?(Numeric) && value == value.to_i ? value.to_i : value) }
      end
    end.prepend("\uFEFF")
  end

  def to_xlsx
    package = Axlsx::Package.new
    workbook = package.workbook
    heading_style = workbook.styles.add_style(b: true, bg_color: 'E8EDF5', fg_color: '172554')
    workbook.add_worksheet(name: worksheet_title) do |sheet|
      sheet.add_row(headers, types: Array.new(headers.size, :string), style: heading_style)
      row_number = 1
      each_item do |item|
        row_number += 1
        values = values_for(item)
        types = [:string, *@fields.map { |field| excel_type_for(field) }, :string, :string]
        sheet.add_row(values, types: types)
      end
      sheet.sheet_view.show_grid_lines = false
      sheet.auto_filter.range = "A1:#{Axlsx::col_ref(headers.size - 1)}#{row_number}"
    end
    package.to_stream.read
  end

  private

  def each_item(&block)
    @inventory.items.preload(:creator).find_each(batch_size: BATCH_SIZE, &block)
  end

  def values_for(item)
    [item.custom_id, *@fields.map { |field| export_value(item.public_send(field.column_name), field.kind) }, item.creator&.username, item.created_at.utc.iso8601]
  end

  def export_value(value, kind)
    return nil if value.nil?
    case kind
    when 'number' then value.to_f
    when 'bool' then value
    else value.to_s
    end
  end

  def excel_type_for(field)
    case field.kind
    when 'number' then :float
    when 'bool' then :boolean
    else :string
    end
  end

  def escape_spreadsheet_formula(value)
    value.match?(/\A[\s\p{Zs}]*[=+\-@]/) ? "'#{value}" : value
  end

  def worksheet_title
    name = @inventory.title.to_s.gsub(/[\[\]:*?\/\\]/, ' ').strip[0, 31]
    name.presence || 'Items'
  end
end
