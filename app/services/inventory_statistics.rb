class InventoryStatistics
  attr_reader :total, :fields

  def initialize(inventory)
    @inventory = inventory
    @total = 0
    @fields = []
  end

  def calculate
    definitions = @inventory.inventory_fields.select(&:active?).sort_by(&:position)
    projections = ['COUNT(*)']
    3.times do |index|
      n = index + 1
      projections.concat([
        "COUNT(number#{n})", "AVG(number#{n})", "MIN(number#{n})", "MAX(number#{n})",
        "COUNT(*) FILTER (WHERE bool#{n} IS TRUE)",
        "COUNT(*) FILTER (WHERE bool#{n} IS FALSE)",
        "COUNT(NULLIF(btrim(text#{n}), ''))", "COUNT(NULLIF(btrim(link#{n}), ''))", "COUNT(NULLIF(btrim(string#{n}), ''))"
      ])
    end
    data = Item.where(inventory_id: @inventory.id).pluck(*projections.map { |sql| Arel.sql(sql) }).first
    @total = data[0].to_i
    aggregates = {}
    3.times do |index|
      n = index + 1
      offset = 1 + index * 9
      aggregates[n] = {
        numeric_count: data[offset].to_i,
        average: data[offset + 1], minimum: data[offset + 2], maximum: data[offset + 3],
        true_count: data[offset + 4].to_i, false_count: data[offset + 5].to_i,
        text_count: data[offset + 6].to_i, link_count: data[offset + 7].to_i,
        string_count: data[offset + 8].to_i
      }
    end

    frequent = Hash.new { |hash, key| hash[key] = [] }
    sql = <<~SQL
      SELECT ranked.slot, ranked.value, ranked.frequency
      FROM (
        SELECT totals.slot, totals.value, totals.frequency,
          ROW_NUMBER() OVER (PARTITION BY totals.slot ORDER BY totals.frequency DESC, totals.value) AS rank
        FROM (
          SELECT entry.slot, entry.value, COUNT(*) AS frequency
          FROM items
          CROSS JOIN LATERAL (VALUES
            ('string1', items.string1),
            ('string2', items.string2),
            ('string3', items.string3)
          ) AS entry(slot, value)
          WHERE items.inventory_id = ? AND NULLIF(btrim(entry.value), '') IS NOT NULL
          GROUP BY entry.slot, entry.value
        ) totals
      ) ranked
      WHERE ranked.rank <= 5
      ORDER BY ranked.slot, ranked.rank
    SQL
    safe_sql = ActiveRecord::Base.sanitize_sql_array([sql, @inventory.id])
    ActiveRecord::Base.connection.select_all(safe_sql).each do |row|
      frequent[row['slot']] << { value: row['value'], count: row['frequency'].to_i }
    end

    @fields = definitions.map do |field|
      { definition: field, summary: aggregates.fetch(field.slot), common: frequent.fetch(field.column_name, []) }
    end
    self
  end
end
