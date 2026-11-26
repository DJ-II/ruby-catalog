require 'test_helper'

class AvailableCustomIdTest < ActiveSupport::TestCase
  CandidateFormat = Struct.new(:candidates, :random) do
    def random?
      random
    end

    def generate(sequence:, at:)
      candidates.shift
    end
  end

  setup do
    user = User.create!(username: 'candidate_owner', email: 'candidate@example.test', password: 'TestingPass123')
    category = Category.find_or_create_by!(name: 'Equipment')
    @inventory = Inventory.create!(creator: user, category: category, title: 'Candidate inventory')
    @inventory.items.create!(custom_id: 'TAKEN', sequence_number: 1, creator: user)
  end

  test 'skips occupied random candidates and returns the first available ID' do
    format = CandidateFormat.new(['TAKEN', 'FREE'] + Array.new(8, 'TAKEN'), true)
    assert_equal 'FREE', AvailableCustomId.generate(@inventory, sequence: 2, format: format)
  end

  test 'stops when all ten candidates are occupied' do
    format = CandidateFormat.new(Array.new(10, 'TAKEN'), true)
    assert_nil AvailableCustomId.generate(@inventory, sequence: 2, format: format)
    assert_empty format.candidates
  end

  test 'deterministic template is generated once' do
    format = CandidateFormat.new(['TAKEN', 'FREE'], false)
    assert_nil AvailableCustomId.generate(@inventory, sequence: 2, format: format)
    assert_equal ['FREE'], format.candidates
  end
end
