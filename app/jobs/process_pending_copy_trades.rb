class ProcessPendingCopyTrades < ApplicationJob

  def perform
   PendingCopyTrade.ready_to_process.find_each do |pending_trade|
     process_trade(pending_trade)
   end
  
   cleanup_old_invalid_trades
  end

  private

  def process_trade(pending_trade)
    pending_trade.process!
   
    begin
      # Try to find or create token pair
      token_pair = CreateTokenPairService.call(
        token_address: pending_trade.token_address,
        chain: pending_trade.chain
      )
     
      if token_pair
        create_copy_trade(pending_trade, token_pair)
        pending_trade.mark_valid!
      else
        # No valid pool found
        pending_trade.mark_invalid!
      end
     
    rescue => e
      Rails.logger.error "Failed to process pending trade #{pending_trade.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # Reset to pending for retry on next run
      pending_trade.update(status: 'pending')
    end
  end

  def create_copy_trade(pending_trade, token_pair)
    CopyTrade.create!(
      wallet_address: pending_trade.wallet_address,
      tx_hash: pending_trade.tx_hash,
      block_number: pending_trade.block_number,
      token_pair: token_pair,
      amount_out: pending_trade.amount_out,
      amount_in: calculate_amount_in(pending_trade.amount_out, token_pair)
    )
  rescue ActiveRecord::RecordNotUnique
    # Trade already exists, mark as valid anyway
    Rails.logger.info "Copy trade already exists for tx: #{pending_trade.tx_hash}"
  end

  def calculate_amount_in(amount_out, token_pair)
    amount_out * token_pair.current_price
  end

  def cleanup_old_invalid_trades
    PendingCopyTrade
      .invalid
      .where('created_at < ?', 24.hours.ago)
      .destroy_all
  end
end