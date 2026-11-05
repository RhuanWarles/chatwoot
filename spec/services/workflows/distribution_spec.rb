require 'rails_helper'

RSpec.describe Workflows::Distribution do
  let(:account) { create(:account) }
  let(:workflow) { account.automation_workflows.create!(name: 'Rodízio', graph: { 'nodes' => [], 'edges' => [] }) }
  let(:people) { create_list(:user, 3, account: account, role: :agent) }

  def split(*percentages)
    people.first(percentages.size).zip(percentages).map { |user, percentage| { 'user_id' => user.id, 'percentage' => percentage } }
  end

  def draw(times, assignees, node: 'a')
    Array.new(times) { described_class.pick!(workflow, node, assignees) }
  end

  describe '.errors' do
    it 'accepts people whose percentages add up to 100' do
      expect(described_class.errors(split(50, 30, 20))).to be_empty
      expect(described_class.errors([{ user_id: 1, percentage: 100 }])).to be_empty
    end

    it 'asks for at least one person' do
      expect(described_class.errors(nil)).not_to be_empty
      expect(described_class.errors([])).not_to be_empty
    end

    it 'refuses percentages that do not add up to 100' do
      expect(described_class.errors(split(50, 30))).to include('the percentages must add up to 100')
      expect(described_class.errors(split(60, 60))).to include('the percentages must add up to 100')
    end

    it 'refuses a percentage that is not a whole number from 1 to 100' do
      expect(described_class.errors(split(0, 100))).to include('every percentage must be a whole number from 1 to 100')
      expect(described_class.errors(split(50.5, 49.5))).to include('every percentage must be a whole number from 1 to 100')
      expect(described_class.errors([{ 'user_id' => 1, 'percentage' => 'metade' }])).not_to be_empty
    end

    it 'refuses the same person twice and entries without a person' do
      twice = [{ 'user_id' => 1, 'percentage' => 50 }, { 'user_id' => 1, 'percentage' => 50 }]

      expect(described_class.errors(twice)).to include('a person can only appear once in the distribution')
      expect(described_class.errors([{ 'percentage' => 100 }])).to include('every person of the distribution needs a user')
    end

    it 'limits how many people can share a step' do
      many = Array.new(51) { |index| { 'user_id' => index + 1, 'percentage' => 1 } }

      expect(described_class.errors(many)).to include('distribution can have at most 50 people')
    end
  end

  describe '.pick!' do
    it 'gives each person exactly their share over every 100 leads' do
      picks = draw(200, split(50, 30, 20))

      expect(picks.tally).to eq(people[0].id => 100, people[1].id => 60, people[2].id => 40)
    end

    it 'spreads the turns instead of handing them out in blocks' do
      first_ten = draw(10, split(50, 30, 20))

      expect(first_ten.tally).to eq(people[0].id => 5, people[1].id => 3, people[2].id => 2)
      expect(first_ten.each_cons(3).none? { |window| window.uniq.size == 1 }).to be(true)
    end

    it 'alternates two people with the same share' do
      expect(draw(4, split(50, 50))).to eq([people[0].id, people[1].id, people[0].id, people[1].id])
    end

    it 'always picks the only person' do
      expect(draw(3, split(100)).uniq).to eq([people[0].id])
    end

    it 'keeps counting between runs' do
      draw(1, split(50, 50))

      expect(described_class.pick!(workflow, 'a', split(50, 50))).to eq(people[1].id)
    end

    it 'keeps a separate count for each step' do
      draw(1, split(50, 50), node: 'a')

      expect(described_class.pick!(workflow, 'b', split(50, 50))).to eq(people[0].id)
    end

    it 'starts over when the people or the percentages change' do
      draw(3, split(50, 50))

      expect(draw(10, split(80, 20)).tally).to eq(people[0].id => 8, people[1].id => 2)
    end

    it 'is removed with the workflow' do
      draw(1, split(50, 50))

      expect { workflow.destroy! }.to change(AutomationDistributionState, :count).by(-1)
    end
  end
end
