class BotCycle < ApplicationRecord
  belongs_to :bot
  has_many :trades

  def buy_count
    trades.where(trade_type: "buy", status: "completed").count
  end

  def sell_count
    trades.where(trade_type: "sell", status: "completed").count
  end

  def last_sell_price
    trades.where(trade_type: "sell", status: "completed").order(created_at: :desc).first&.price
  end

  def last_buy_at
    trades.where(trade_type: "buy", status: "completed").order(created_at: :desc).first&.created_at
  end

  def last_sell_at
    trades.where(trade_type: "sell", status: "completed").order(created_at: :desc).first&.created_at
  end

  def last_trade_at
    trades.where(status: "completed").order(created_at: :desc).first&.created_at
  end
end
