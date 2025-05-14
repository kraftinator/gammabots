class NonceMonitorSchedulerJob < ApplicationJob
  def perform
    Wallet.pluck(:id).each do |wallet_id|
      NonceMonitorJob.perform_later(wallet_id)
    end
  end
end
