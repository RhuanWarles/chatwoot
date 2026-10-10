desc 'Grant credits or seconds: saas:credit[account_id,text_credits|voice_seconds,units,unique_reference]'
task 'saas:credit', [:account_id, :resource, :units, :reference] => :environment do |_task, args|
  raise ArgumentError, 'reference is required' if args[:reference].blank?
  raise ArgumentError, 'invalid resource' unless Saas::Wallet::RESOURCES.include?(args[:resource])

  wallet = Saas::Wallet.for_account(Account.find(args[:account_id]), args[:resource])
  wallet.credit!(units: Integer(args[:units]), reference: args[:reference])
  puts "Balance: #{wallet.reload.balance_units} #{wallet.resource}; available: #{wallet.available_units}"
end

desc 'Release expired platform text reservations for AI Agents'
task 'saas:reconcile_ai_agent_credits' => :environment do
  Saas::Wallet.release_expired!
end

desc 'Assign a platform-owned Vapi assistant and number: saas:connect_voice[account_id,assistant_id,phone_number_id]'
task 'saas:connect_voice', [:account_id, :assistant_id, :phone_number_id] => :environment do |_task, args|
  raise 'Configure VAPI_PRIVATE_KEY, VAPI_WEBHOOK_SECRET and VAPI_WEBHOOK_URL first' unless Saas::VapiClient.configured?
  raise ArgumentError, 'VAPI_WEBHOOK_URL must be HTTPS' unless ENV.fetch('VAPI_WEBHOOK_URL').start_with?('https://')

  %i[assistant_id phone_number_id].each do |field|
    raise ArgumentError, "invalid #{field}" unless args[field]&.match?(/\A[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}\z/i)
  end
  account = Account.find(args[:account_id])
  account.with_lock do
    settings = account.saas_ai_setting || account.build_saas_ai_setting
    settings.update!(vapi_assistant_id: args[:assistant_id], vapi_phone_number_id: args[:phone_number_id],
                     inbound_enabled: false, outbound_enabled: false)
  end
  Saas::VapiClient.new.configure_phone(args[:phone_number_id])
  puts 'Number connected. Enable incoming/outgoing calls in AI & Voice after adding minutes.'
end

desc 'Reconcile calls with missing end reports: saas:reconcile_voice[account_id]'
task 'saas:reconcile_voice', [:account_id] => :environment do |_task, args|
  Account.find(args[:account_id]).saas_voice_calls.where.not(status: %w[ended failed]).where.not(provider_call_id: nil).find_each do |call|
    result = Saas::VapiClient.new.get_call(call.provider_call_id)
    next unless result['status'] == 'ended'

    Saas::VapiEventService.new(result.merge('type' => 'end-of-call-report', 'call' => result)).perform
    puts "Reconciled call #{call.id}"
  end
end
