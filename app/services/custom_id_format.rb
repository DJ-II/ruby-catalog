require 'securerandom'

class CustomIdFormat
  MAX_PARTS = 15
  MAX_ID_LENGTH = 200
  KINDS = %w[fixed random20 random32 random6 random9 guid datetime sequence].freeze
  DEFAULT_PATTERNS = {
    'fixed' => 'INV-',
    'random20' => 'X5',
    'random32' => 'X8',
    'random6' => 'D6',
    'random9' => 'D9',
    'guid' => 'D',
    'datetime' => 'yyyy',
    'sequence' => 'D3'
  }.freeze
  DATE_TOKENS = {
    'yyyy' => ['%Y', '\\d{4}'],
    'ddd' => ['%a', '[A-Za-z]{3}'],
    'yy' => ['%y', '\\d{2}'],
    'MM' => ['%m', '(?:0[1-9]|1[0-2])'],
    'dd' => ['%d', '(?:0[1-9]|[12]\\d|3[01])'],
    'HH' => ['%H', '(?:[01]\\d|2[0-3])'],
    'mm' => ['%M', '[0-5]\\d'],
    'ss' => ['%S', '[0-5]\\d']
  }.freeze
  DATE_SEPARATORS = /\A[-_ .:\/]\z/
  GUID_HEX = '[0-9a-fA-F]'
  GUID_PATTERN = "#{GUID_HEX}{8}-#{GUID_HEX}{4}-#{GUID_HEX}{4}-#{GUID_HEX}{4}-#{GUID_HEX}{12}"

  class InvalidFormat < StandardError; end

  def initialize(parts)
    @parts = parts.sort_by { |part| value(part, :position).to_i }
    raise InvalidFormat, I18n.t('ids.errors.too_many', count: MAX_PARTS) if @parts.length > MAX_PARTS
    @parts.each { |part| self.class.validate_part!(value(part, :kind), value(part, :pattern)) }
  end

  def empty?
    @parts.empty?
  end

  def random?
    @parts.any? { |part| %w[random20 random32 random6 random9 guid].include?(value(part, :kind)) }
  end

  def generate(sequence:, at: Time.current, sample: false)
    return 'INV-%06d' % sequence if empty?
    result = @parts.map do |part|
      kind = value(part, :kind)
      pattern = value(part, :pattern)
      case kind
      when 'fixed' then pattern
      when 'random20' then format_number(sample ? 0xA7E3A : SecureRandom.random_number(1 << 20), pattern)
      when 'random32' then format_number(sample ? 0xE74FA329 : SecureRandom.random_number(1 << 32), pattern)
      when 'random6' then format_number(sample ? 123_456 : SecureRandom.random_number(1_000_000), pattern)
      when 'random9' then format_number(sample ? 123_456_789 : SecureRandom.random_number(1_000_000_000), pattern)
      when 'guid' then format_guid(sample ? 'A1B2C3D4-0123-4567-89AB-0123456789AB' : SecureRandom.uuid.upcase, pattern)
      when 'datetime' then format_datetime(at, pattern)
      when 'sequence' then format_number(sequence, pattern)
      end
    end.join
    raise InvalidFormat, I18n.t('ids.errors.generated_too_long', count: MAX_ID_LENGTH) if result.length > MAX_ID_LENGTH
    result
  end

  def valid_id?(custom_id)
    return false unless custom_id.is_a?(String) && custom_id.present? && custom_id.length <= MAX_ID_LENGTH
    return true if empty?
    match_part(custom_id, 0, 0, {})
  end

  def self.validate_part!(kind, pattern)
    raise InvalidFormat, I18n.t('ids.errors.unknown_kind') unless KINDS.include?(kind)
    raise InvalidFormat, I18n.t('ids.errors.empty_pattern') if !pattern.is_a?(String) || pattern.empty?
    raise InvalidFormat, I18n.t('ids.errors.part_too_long', count: MAX_ID_LENGTH) if pattern.length > MAX_ID_LENGTH
    case kind
    when 'random20', 'random32', 'random6', 'random9', 'sequence'
      number_options(pattern)
    when 'guid'
      raise InvalidFormat, I18n.t('ids.errors.guid_format') unless %w[N D B P].include?(pattern)
    when 'datetime'
      date_pieces(pattern)
    end
    true
  end

  def self.number_options(pattern)
    match = /\A([DX])((?:[1-9][0-9]?)?)\z/.match(pattern)
    raise InvalidFormat, I18n.t('ids.errors.number_format') unless match
    [match[1] == 'X' ? 16 : 10, match[2].empty? ? 0 : match[2].to_i]
  end

  def self.date_pieces(pattern)
    parts = []
    index = 0
    while index < pattern.length
      token = DATE_TOKENS.keys.find { |candidate| pattern[index, candidate.length] == candidate }
      if token
        parts << DATE_TOKENS.fetch(token)
        index += token.length
      elsif DATE_SEPARATORS.match?(pattern[index])
        char = pattern[index]
        parts << [char, Regexp.escape(char)]
        index += 1
      else
        raise InvalidFormat, I18n.t('ids.errors.date_format')
      end
    end
    parts
  end

  def self.guid_regex(pattern)
    case pattern
    when 'N' then "#{GUID_HEX}{32}"
    when 'D' then GUID_PATTERN
    when 'B' then "\\{#{GUID_PATTERN}\\}"
    when 'P' then "\\(#{GUID_PATTERN}\\)"
    end
  end

  private

  def match_part(custom_id, part_index, offset, memo)
    return offset == custom_id.length if part_index == @parts.length
    key = [part_index, offset]
    return memo.fetch(key) if memo.key?(key)
    part = @parts[part_index]
    kind = value(part, :kind)
    pattern = value(part, :pattern)
    matches = lambda { |length| match_part(custom_id, part_index + 1, offset + length, memo) }
    result = case kind
             when 'fixed'
               custom_id[offset, pattern.length] == pattern && matches.call(pattern.length)
             when 'guid', 'datetime'
               expression = kind == 'guid' ? self.class.guid_regex(pattern) : self.class.date_pieces(pattern).map(&:last).join
               matched = Regexp.new("\\A#{expression}").match(custom_id[offset..])
               matched && matches.call(matched[0].length)
             else
               base, width = self.class.number_options(pattern)
               limit = { 'random20' => (1 << 20) - 1, 'random32' => (1 << 32) - 1,
                         'random6' => 999_999, 'random9' => 999_999_999 }[kind]
               min_width = width.zero? ? 1 : width
               max_width = limit.nil? ? custom_id.length - offset : [min_width, limit.to_s(base).length].max
               (min_width..[max_width, custom_id.length - offset].min).any? do |length|
                 segment = custom_id[offset, length]
                 allowed = base == 16 ? /\A[0-9a-fA-F]+\z/ : /\A[0-9]+\z/
                 segment.match?(allowed) && (limit.nil? || segment.to_i(base) <= limit) && matches.call(length)
               end
             end
    memo[key] = !!result
  end

  def value(part, attribute)
    part.respond_to?(attribute) ? part.public_send(attribute) : part.fetch(attribute)
  end

  def format_number(number, pattern)
    base, width = self.class.number_options(pattern)
    number.to_s(base).upcase.rjust(width, '0')
  end

  def format_guid(guid, pattern)
    case pattern
    when 'N' then guid.delete('-')
    when 'D' then guid
    when 'B' then "{#{guid}}"
    when 'P' then "(#{guid})"
    end
  end

  def format_datetime(at, pattern)
    at.strftime(self.class.date_pieces(pattern).map(&:first).join)
  end
end
