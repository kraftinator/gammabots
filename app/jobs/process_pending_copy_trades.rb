class ProcessPendingCopyTrades < ApplicationJob

  def perform
    PendingCopyTrade.ready_to_process.each do |pending_copy_trade|
    end
  end
  
end