# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountUser do
  include ActiveJob::TestHelper

  let!(:account_user) { create(:account_user) }
  let!(:inbox) { create(:inbox, account: account_user.account) }

  describe 'notification_settings' do
    it 'gets created with the right default settings' do
      expect(account_user.user.notification_settings).not_to be_nil

      expect(account_user.user.notification_settings.first.email_conversation_creation?).to be(false)
      expect(account_user.user.notification_settings.first.email_conversation_assignment?).to be(true)
    end
  end

  describe 'permissions' do
    it 'returns the right permissions' do
      expect(account_user.permissions).to eq(['agent'])
    end

    it 'returns the right permissions for administrator' do
      account_user.administrator!
      expect(account_user.permissions).to eq(['administrator'])
    end
  end

  describe 'hidden fields' do
    it 'is nil when the list is nil, empty or blank' do
      account_user.update!(hidden_fields: ['contact.email'])
      [nil, [], ['', nil]].each do |value|
        account_user.update!(hidden_fields: value)
        expect(account_user.reload.hidden_fields).to be_nil
      end
    end

    it 'accepts the known fields and the custom fields of contacts, conversations and deals' do
      fields = %w[contact.phone_number contact.custom.cpf conversation.custom.origem deal.custom.renda_mensal deal.value]

      expect(account_user.update(hidden_fields: fields)).to be(true)
      expect(account_user.reload.hidden_fields).to eq(fields)
    end

    it 'drops repeated fields' do
      account_user.update!(hidden_fields: %w[contact.email contact.email])

      expect(account_user.reload.hidden_fields).to eq(['contact.email'])
    end

    it 'refuses fields that do not exist' do
      expect(account_user.update(hidden_fields: %w[contact.email contact.password])).to be(false)
      expect(account_user.errors[:hidden_fields].first).to include('contact.password')
    end

    it 'refuses a custom field without a key or of another record' do
      expect(account_user.update(hidden_fields: ['contact.custom.'])).to be(false)
      expect(account_user.update(hidden_fields: ['inbox.custom.cpf'])).to be(false)
    end
  end

  describe '#may_resolve_conversations?' do
    it 'is true for an agent by default' do
      expect(account_user.may_resolve_conversations?).to be(true)
    end

    it 'is false for an agent whose permission was switched off' do
      account_user.update!(can_resolve_conversations: false)

      expect(account_user.may_resolve_conversations?).to be(false)
    end

    it 'is always true for an administrator' do
      account_user.update!(role: :administrator, can_resolve_conversations: false)

      expect(account_user.may_resolve_conversations?).to be(true)
    end
  end

  describe 'destroy call agent::destroy service' do
    it 'gets created with the right default settings' do
      create(:conversation, account: account_user.account, assignee: account_user.user, inbox: inbox)
      user = account_user.user

      expect(user.assigned_conversations.count).to eq(1)

      perform_enqueued_jobs do
        account_user.destroy!
      end

      expect(user.assigned_conversations.count).to eq(0)
    end
  end

  describe 'filtered unread count invalidation' do
    let(:account) { create(:account) }
    let(:user) { create(:user) }
    let(:invalidator) { instance_double(Conversations::UnreadCounts::FilteredCountInvalidator, user_visibility_changed!: true) }

    before do
      allow(Conversations::UnreadCounts::FilteredCountInvalidator).to receive(:new).and_return(invalidator)
      allow(Rails.configuration.dispatcher).to receive(:dispatch)
    end

    it 'invalidates filtered counts when the user is added to an account' do
      create(:account_user, account: account, user: user)

      expect(invalidator).to have_received(:user_visibility_changed!).with(user_id: user.id)
    end

    it 'invalidates filtered counts when the user role changes' do
      account_user = create(:account_user, account: account, user: user)

      account_user.update!(role: :administrator)

      expect(invalidator).to have_received(:user_visibility_changed!).with(user_id: user.id).twice
      expect(Rails.configuration.dispatcher).to have_received(:dispatch).with(
        'account.cache_invalidated',
        kind_of(Time),
        account: account,
        cache_keys: account.cache_keys
      )
    end

    it 'invalidates filtered counts when the user is removed from an account' do
      account_user = create(:account_user, account: account, user: user)

      account_user.destroy!

      expect(invalidator).to have_received(:user_visibility_changed!).with(user_id: user.id).twice
    end
  end
end
