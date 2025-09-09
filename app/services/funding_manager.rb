class FundingManager
  CONFIRMATION_DELAY = 2.seconds

  def self.confirm_funding!(bot)
    return unless bot.pending_funding?
    ConfirmFundingJob.set(wait: CONFIRMATION_DELAY).perform_later(bot.id)
  end
end
