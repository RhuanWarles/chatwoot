# frozen_string_literal: true

namespace :db do
  desc 'Creates the initial confirmed SuperAdmin when bootstrap credentials are configured'
  task bootstrap_admin: :environment do
    email = ENV.fetch('BOOTSTRAP_ADMIN_EMAIL', '').strip.downcase
    password = ENV.fetch('BOOTSTRAP_ADMIN_PASSWORD', '')
    name = ENV.fetch('BOOTSTRAP_ADMIN_NAME', 'Administrador').strip
    account_name = ENV.fetch('BOOTSTRAP_ADMIN_ACCOUNT_NAME', 'Chatwoot').strip

    if email.blank? || password.blank?
      puts 'Bootstrap admin credentials are not configured; skipping.'
      next
    end

    if User.exists?(email: email)
      puts "Bootstrap admin #{email} already exists; skipping."
      next
    end

    AccountBuilder.new(
      account_name: account_name,
      email: email,
      confirmed: true,
      user_full_name: name,
      user_password: password,
      super_admin: true
    ).perform

    puts "Created confirmed SuperAdmin #{email}."
  end
end
