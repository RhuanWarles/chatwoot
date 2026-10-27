require 'rails_helper'

RSpec.describe Crm::ResponderReport do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:brenda) { create(:user, account: account, role: :agent) }
  let(:rodolpho) { create(:user, account: account, role: :agent) }
  let(:pipeline) { account.crm_pipelines.create!(name: 'Comercial') }
  let(:stage) { account.crm_pipeline_stages.create!(pipeline: pipeline, name: 'Novo', position: 0) }
  let(:restaurants) { account.crm_segments.create!(name: 'Restaurantes') }
  let(:clinics) { account.crm_segments.create!(name: 'Clínicas') }
  let(:this_month) { Time.current.strftime('%Y-%m') }
  let(:last_month) { 1.month.ago.strftime('%Y-%m') }

  def conversation_for(contact)
    create(:conversation, account: account, inbox: inbox, contact: contact)
  end

  def reply(conversation, sender: nil, at: Time.current, **attributes)
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, sender: sender,
                     created_at: at, **attributes)
  end

  def ai_reply(conversation, at: Time.current)
    reply(conversation, at: at, content_attributes: { 'generated_by_ai' => true })
  end

  def deal_for(contact, **attributes)
    account.crm_deals.create!(pipeline: pipeline, pipeline_stage: stage, contact: contact, name: 'Lead', **attributes)
  end

  def report(**params)
    described_class.new(account, params).perform
  end

  def month(data, label)
    data[:months].find { |row| row[:month] == label }
  end

  describe 'months' do
    it 'lists the last 6 months, oldest first, even when nothing happened' do
      months = report[:months].pluck(:month)

      expect(months.length).to eq(6)
      expect(months.last).to eq(this_month)
      expect(months).to eq(months.sort)
      expect(report[:months].sum { |row| row[:ai_replies] + row[:human_replies] }).to eq(0)
    end

    it 'accepts 1 to 24 months' do
      expect(report(months: 3)[:months].length).to eq(3)
      expect { report(months: 25) }.to raise_error(ArgumentError, 'invalid_months')
      expect { report(months: 0) }.to raise_error(ArgumentError, 'invalid_months')
      expect { report(months: 'x') }.to raise_error(ArgumentError, 'invalid_months')
    end
  end

  describe 'AI versus people' do
    let(:conversation) { conversation_for(create(:contact, account: account)) }

    it 'counts the replies of each side per month' do
      ai_reply(conversation)
      ai_reply(conversation)
      reply(conversation, sender: brenda)
      reply(conversation, sender: brenda, at: 1.month.ago)

      data = report

      expect(month(data, this_month)).to include(ai_replies: 2, human_replies: 1, ai_share: 66.67)
      expect(month(data, last_month)).to include(ai_replies: 0, human_replies: 1, ai_share: 0.0)
      expect(data[:totals]).to include(ai_replies: 2, human_replies: 2, ai_share: 50.0)
    end

    it 'does not count customer messages or private notes' do
      create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming)
      reply(conversation, sender: brenda, private: true)

      expect(month(report, this_month)).to include(ai_replies: 0, human_replies: 0)
    end

    it 'tells conversations handled only by the AI, only by people, or by both' do
      only_ai = conversation_for(create(:contact, account: account))
      only_human = conversation_for(create(:contact, account: account))
      both = conversation_for(create(:contact, account: account))
      ai_reply(only_ai)
      reply(only_human, sender: brenda)
      ai_reply(both)
      reply(both, sender: rodolpho)

      row = month(report, this_month)

      expect(row[:conversations]).to eq(total: 3, ai_only: 1, human_only: 1, mixed: 1)
      expect(row[:ai_only_share]).to eq(33.33)
    end

    it 'ignores other accounts' do
      other = create(:account)
      other_inbox = create(:inbox, account: other)
      foreign = create(:conversation, account: other, inbox: other_inbox)
      create(:message, account: other, inbox: other_inbox, conversation: foreign, message_type: :outgoing,
                       content_attributes: { 'generated_by_ai' => true })

      expect(report[:totals]).to include(ai_replies: 0, human_replies: 0)
    end
  end

  describe 'filters' do
    let(:restaurant_contact) { create(:contact, account: account) }
    let(:clinic_contact) { create(:contact, account: account) }
    let(:lonely_contact) { create(:contact, account: account) }

    before do
      deal_for(restaurant_contact, segment: restaurants, owner: brenda)
      deal_for(clinic_contact, segment: clinics, owner: rodolpho)
      ai_reply(conversation_for(restaurant_contact))
      reply(conversation_for(clinic_contact), sender: brenda)
      reply(conversation_for(lonely_contact), sender: rodolpho)
    end

    it 'keeps the customers of the chosen segment' do
      data = report(segment_ids: [restaurants.id])

      expect(data[:totals]).to include(ai_replies: 1, human_replies: 0)
    end

    it 'can pick the customers that have no segment' do
      account.crm_deals.find_by(contact: lonely_contact) || deal_for(lonely_contact)

      expect(report(segment_ids: ['none'])[:totals]).to include(ai_replies: 0, human_replies: 1)
    end

    it 'keeps the customers owned by the chosen seller, whoever answered them' do
      data = report(owner_ids: [rodolpho.id])

      expect(data[:totals]).to include(ai_replies: 0, human_replies: 1)
    end

    it 'keeps the conversations answered by any of the chosen people or the AI' do
      data = report(answered_by: ['ai', brenda.id])

      expect(data[:totals]).to include(ai_replies: 1, human_replies: 1)
    end

    it 'counts all the replies of a conversation the chosen person took part in' do
      shared = conversation_for(restaurant_contact)
      reply(shared, sender: rodolpho)

      data = report(answered_by: [rodolpho.id], segment_ids: [restaurants.id])

      expect(data[:totals]).to include(human_replies: 1)
    end

    it 'combines the filters' do
      data = report(owner_ids: [brenda.id], answered_by: ['ai'], segment_ids: [restaurants.id])

      expect(data[:totals]).to include(ai_replies: 1, human_replies: 0)
      expect(report(owner_ids: [brenda.id], answered_by: [rodolpho.id])[:totals]).to include(ai_replies: 0, human_replies: 0)
    end

    it 'rejects values that are not ids' do
      expect { report(owner_ids: ['abc']) }.to raise_error(ArgumentError, 'invalid_owner_ids')
      expect { report(answered_by: ['none']) }.to raise_error(ArgumentError, 'invalid_answered_by')
      expect { report(segment_ids: ['1; DROP']) }.to raise_error(ArgumentError, 'invalid_segment_ids')
    end
  end

  it 'offers the people and the segments of the account to filter by' do
    brenda
    restaurants

    data = report

    expect(data[:people]).to include(id: brenda.id, name: brenda.name)
    expect(data[:segments]).to eq([{ id: restaurants.id, name: 'Restaurantes' }])
  end
end
