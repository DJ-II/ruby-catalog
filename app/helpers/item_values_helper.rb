module ItemValuesHelper
  def inventory_number_display(value, precision: 3, locale: I18n.locale)
    return '—' if value.nil?
    number_with_precision(value, precision: precision, strip_insignificant_zeros: true, delimiter: '', locale: locale)
  end
end
