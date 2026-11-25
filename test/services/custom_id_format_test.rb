require 'test_helper'

class CustomIdFormatTest < ActiveSupport::TestCase
  def part(kind, pattern, position)
    { kind: kind, pattern: pattern, position: position }
  end

  test 'combines Unicode fixed text random hex sequence and creation year' do
    format = CustomIdFormat.new([
      part('fixed', "\u{1F4DA}-", 0),
      part('random20', 'X5', 1),
      part('fixed', '_', 2),
      part('sequence', 'D3', 3),
      part('fixed', '_', 4),
      part('datetime', 'yyyy', 5)
    ])
    sample = format.generate(sequence: 13, at: Time.utc(2025, 1, 9), sample: true)
    assert_equal "\u{1F4DA}-A7E3A_013_2025", sample
    assert format.valid_id?(sample)
    assert_not format.valid_id?("\u{1F4DA}-ZZZZZ_013_2025")
  end

  test 'all kinds produce IDs accepted by their own format' do
    CustomIdFormat::KINDS.each do |kind|
      pattern = CustomIdFormat::DEFAULT_PATTERNS.fetch(kind)
      format = CustomIdFormat.new([part(kind, pattern, 0)])
      [false, true].each do |sample|
        generated = format.generate(sequence: 41, sample: sample)
        assert format.valid_id?(generated), "#{kind}: #{generated}"
      end
    end
  end

  test 'random numeric validation rejects out of range numbers' do
    format = CustomIdFormat.new([part('random20', 'D1', 0)])
    assert format.valid_id?('1048575')
    assert_not format.valid_id?('1048576')
    assert_not format.valid_id?('letters')
  end

  test 'date tokens are validated' do
    format = CustomIdFormat.new([part('datetime', 'yyyy-MM-dd_HH:mm:ss', 0)])
    assert format.valid_id?('2026-11-23_16:45:03')
    assert_not format.valid_id?('2026-13-23_16:45:03')
    assert_raises(CustomIdFormat::InvalidFormat) do
      CustomIdFormat.new([part('datetime', 'yyyy-FOO-dd', 0)])
    end
  end

  test 'GUID variants have the expected separators' do
    %w[N D B P].each do |pattern|
      format = CustomIdFormat.new([part('guid', pattern, 0)])
      assert format.valid_id?(format.generate(sequence: 1))
    end
  end

  test 'empty template keeps existing default generation and manual IDs' do
    format = CustomIdFormat.new([])
    assert_equal 'INV-000012', format.generate(sequence: 12)
    assert format.valid_id?('MY-OWN-NUMBER')
  end

  test 'sequence format allows extra digits after minimum width' do
    format = CustomIdFormat.new([part('sequence', 'D3', 0)])
    assert_equal '1000', format.generate(sequence: 1000)
    assert format.valid_id?('1000')
  end
end
