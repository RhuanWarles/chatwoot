class Saas::AiAgents::ReconcileCreditsJob < ApplicationJob
  queue_as :low

  def perform
    Saas::Wallet.release_expired!
  end
end
