class AvailableCustomId
  MAX_ATTEMPTS = 10

  def self.generate(inventory, sequence:, format: inventory.custom_id_format, at: Time.current)
    candidates = Array.new(format.random? ? MAX_ATTEMPTS : 1) { format.generate(sequence: sequence, at: at) }.uniq
    taken = inventory.items.where(custom_id: candidates).pluck(:custom_id)
    (candidates - taken).first
  end
end
