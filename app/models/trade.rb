class Trade < ApplicationRecord
  CONFIRMATION_DELAY = 5.seconds

  belongs_to :bot
  belongs_to :bot_cycle
  before_validation :assign_bot_cycle, on: :create
  after_commit :schedule_confirmation, :enqueue_infinite_approval, on: :create
  after_update :clear_reset_request_on_failed_sell, if: :saved_change_to_status?

  validates :trade_type, presence: true, inclusion: { in: %w[buy sell] }
  validates :status, presence: true, inclusion: { in: %w[pending completed failed] }

  validates :price, numericality: { greater_than: 0 }, if: -> { completed? }
  validates :amount_in, numericality: { greater_than: 0 }, if: -> { completed? }
  validates :amount_out, numericality: { greater_than: 0 }, if: -> { completed? }
  validates :total_value, numericality: { greater_than: 0 }, if: -> { completed? }

  validates :executed_at, presence: true

  def pending?
    status == "pending"
  end

  def completed?
    status == "completed"
  end

  def failed?
    status == "failed"
  end

  def buy?
    trade_type == "buy"
  end
  
  def sell?
    trade_type == "sell"
  end
  
  def token_pair
    bot.token_pair
  end

  def total_value
    amount_out * price
  end

  def analyze_metrics
    # Extract string values (or nil)
    cma_str = metrics["cma"]
    lma_str = metrics["lma"]
    tma_str = metrics["tma"]
    cpr_str = metrics["cpr"]
    ppr_str = metrics["ppr"]
    lps_str = metrics["lps"]
    lmc_str = metrics["lmc"]

    # cma > lma
    if cma_str && lma_str
      cma = BigDecimal(cma_str)
      lma = BigDecimal(lma_str)
      unless lma.zero?
        cma_lma_pct = (cma - lma) / lma * 100
        puts "cma > lma: #{cma_lma_pct.to_f.round(6)}%"
      end
    end

    # lma > tma
    if lma_str && tma_str
      lma = BigDecimal(lma_str)
      tma = BigDecimal(tma_str)
      unless tma.zero?
        lma_tma_pct = (lma - tma) / tma * 100
        puts "lma > tma: #{lma_tma_pct.to_f.round(6)}%"
      end
    end

    # cma > tma
    #if cma_str && tma_str
    #  cma = BigDecimal(cma_str)
    #  tma = BigDecimal(tma_str)
    #  unless tma.zero?
    #    cma_tma_pct = (cma - tma) / tma * 100
    #    puts "cma > tma: #{cma_tma_pct.to_f.round(6)}%"
    #  end
    #end

    # cpr > cma
    if cpr_str && cma_str
      cpr = BigDecimal(cpr_str)
      cma = BigDecimal(cma_str)
      unless cma.zero?
        cpr_cma_pct = (cpr - cma) / cma * 100
        puts "cpr > cma: #{cpr_cma_pct.to_f.round(6)}%"
      end
    end

    # cpr > ppr
    if cpr_str && ppr_str
      cpr = BigDecimal(cpr_str)
      ppr = BigDecimal(ppr_str)
      unless ppr.zero?
        cpr_ppr_pct = (cpr - ppr) / ppr * 100
        puts "cpr > ppr: #{cpr_ppr_pct.to_f.round(6)}%"
      end
    end

    # cpr > lps
    if cpr_str && lps_str
      cpr = BigDecimal(cpr_str)
      lps = BigDecimal(lps_str)
      unless lps.zero?
        cpr_lps_pct = (cpr - lps) / lps * 100
        puts "cpr > lps: #{cpr_lps_pct.to_f.round(6)}%"
      end
    end

    # cma > lmc
    if cma_str && lmc_str
      cma = BigDecimal(cma_str)
      lmc = BigDecimal(lmc_str)
      unless lmc.zero?
        cma_lmc_pct = (cma - lmc) / lmc * 100
        puts "cma > lmc: #{cma_lmc_pct.to_f.round(6)}%"
      end
    end

    # ppr == lps
    if ppr_str && lps_str
      ppr = BigDecimal(ppr_str)
      lps = BigDecimal(lps_str)
      if ppr == lps
        puts "ppr = lps: true"
      else
        puts "ppr = lps: false"
      end
    end

    vst_str = metrics["vst"].to_s
    vlt_str = metrics["vlt"].to_s

    if vst_str.present? && vlt_str.present?
      vst = BigDecimal(vst_str.to_s)
      vlt = BigDecimal(vlt_str.to_s)

      # absolute difference
      diff = vst - vlt
      puts "vst - vlt: #{diff.to_f.round(6)}"

      # percentage difference (relative to vlt), guard against zero
      unless vlt.zero?
        diff_pct = diff / vlt * 100
        puts "vst > vlt: #{diff_pct.to_f.round(6)}%"
      end
    end

    ssd_str = metrics["ssd"]
    lsd_str = metrics["lsd"]

    if ssd_str && lsd_str
      ssd = BigDecimal(ssd_str.to_s)
      lsd = BigDecimal(lsd_str.to_s)

      # absolute difference
      diff = ssd - lsd
      puts "ssd - lsd: #{diff.to_f.round(6)}"

      # percentage difference (relative to lsd), guard against zero
      unless lsd.zero?
        diff_pct = diff / lsd * 100
        puts "ssd > lsd: #{diff_pct.to_f.round(6)}%"
      end
    end
    
    puts "ssd: #{ssd_str.to_s[0..6]}, lsd: #{lsd_str.to_s[0..6]}" if ssd_str && lsd_str
    puts "vst: #{vst_str[0..6]}, vlt: #{vlt_str[0..6]}" if vst_str && vlt_str
  end

  private

  def schedule_confirmation
    ConfirmTradeJob.set(wait: CONFIRMATION_DELAY).perform_later(self.id)
  end

  def enqueue_infinite_approval
    return unless buy?
    ApprovalManager.ensure_infinite!(
      wallet:       bot.user.wallet_for_chain(bot.chain),
      token:        bot.token_pair.base_token,
      provider_url: bot.provider_url
    )
  end

  def assign_bot_cycle
    self.bot_cycle = bot.current_cycle
  end

  def clear_reset_request_on_failed_sell
    return unless sell? && failed?
    bot_cycle.update!(reset_requested_at: nil)
  end
end
