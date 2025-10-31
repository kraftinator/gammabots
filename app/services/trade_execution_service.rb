class TradeExecutionService
  ZERO_EX_API_KEY = Rails.application.credentials.dig(:zero_ex, :api_key)

  def self.buy(vars)
    bot = vars[:bot]
    provider_url = bot.provider_url
    min_amount_out = bot.min_amount_out_for_initial_buy

    puts "========================================================"
    puts "TradeExecutionService::buy"
    puts "bot: #{bot.id}, token: #{bot.token_pair.base_token.symbol}, min_amount_out: #{min_amount_out.to_s}"
    puts "========================================================"
    
    sell_token_amount = bot.first_cycle? ? 
      bot.current_cycle.quote_token_amount : bot.current_cycle.quote_token_amount * 0.9999999999
    
    wallet = bot.user.wallet_for_chain(bot.chain)
    token_pair = bot.token_pair
    sell_token = token_pair.quote_token
    buy_token = token_pair.base_token
    result = EthersService.swap(
      wallet, 
      sell_token.contract_address, 
      buy_token.contract_address, 
      sell_token_amount, 
      sell_token.decimals, 
      ZERO_EX_API_KEY, 
      provider_url
    )

    nonce   = result["nonce"]
    tx_hash = result["txHash"]
    success = result["success"]
    
    trade = nil
    if tx_hash.present?
      puts "Swap (buy) submitted! Tx Hash: #{tx_hash}"
      trade = Trade.create!(
        bot: bot,
        trade_type: :buy,
        tx_hash: tx_hash,
        nonce: nonce,
        status: :pending,
        executed_at: Time.current,
        metrics: build_metrics(vars),
        listed_price: token_pair.current_price
      )
      puts "Trade (buy) created: #{trade.id}"
    end

    if !success || tx_hash.blank?
      BotEvent.create!(
        bot:        bot,
        event_type: "trade_failed",
        payload: {
          class:            "TradeExecutionService",
          method:           "buy",
          stage:            result["stage"],
          code:             result["code"],
          message:          result["message"],
          http_status:      result["http_status"],
          nonce:            result["nonce"],
          tx_hash:          result["tx_hash"],
          bump_nonce:       result["bumpNonce"],
          allowance:        result["allowance"],
          attempted_amount: bot.current_cycle.quote_token_amount,
          min_amount_out:   min_amount_out,
          raw:              result["raw"]
        }
      )

      handle_approval(wallet, result, provider_url)

      puts "========================================================"
      puts "TradeExecutionService::buy - Swap failed"
      puts "bot: #{bot.id}, token: #{bot.token_pair.base_token.symbol}, min_amount_out: #{min_amount_out.to_s}"
      puts "ERROR: #{result}"
      puts "========================================================"
    end

    trade
  end

  def self.sell(vars, sell_token_amount, min_amount_out)
    bot = vars[:bot]
    provider_url = bot.provider_url

    puts "========================================================"
    puts "Calling TradeExecutionService::sell"
    puts "bot: #{bot.id}, token: #{bot.token_pair.base_token.symbol}, sell_token_amount: #{sell_token_amount.to_s} min_amount_out: #{min_amount_out.to_s}"
    puts "========================================================"
    
    wallet = bot.user.wallet_for_chain(bot.chain)
    token_pair = bot.token_pair
    sell_token = token_pair.base_token
    buy_token = token_pair.quote_token

    # Adjust sell_token_amount
    raw_amount = sell_token_amount.to_d * BigDecimal('0.9999999999')
    adj_amount = BigDecimal(raw_amount, 30)  
    adj_amount_trimmed = adj_amount.round(sell_token.decimals, :down)

    result = EthersService.swap(
      wallet, 
      sell_token.contract_address, 
      buy_token.contract_address, 
      adj_amount_trimmed,
      sell_token.decimals, 
      ZERO_EX_API_KEY, 
      provider_url
    )

    nonce   = result["nonce"]
    tx_hash = result["txHash"]
    success = result["success"]
    
    trade = nil
    if tx_hash.present?
      puts "Swap (sell) submitted! Transaction Hash: #{tx_hash}"

      trade = Trade.create!(
        bot: bot,
        trade_type: :sell,
        tx_hash: tx_hash,
        nonce: nonce,
        status: :pending,
        executed_at: Time.current,
        metrics: build_metrics(vars),
        listed_price: bot.token_pair.current_price
      )

      puts "Trade (sell) created: #{trade.id}"
    end

    if !success || tx_hash.blank?
      reason = result.dig("error", "reason")
      event_type = "trade_failed"
      BotEvent.create!(
        bot:        bot,
        event_type: "trade_failed",
        payload: {
          class:            "TradeExecutionService",
          method:           "buy",
          stage:            result["stage"],
          code:             result["code"],
          message:          result["message"],
          http_status:      result["http_status"],
          nonce:            result["nonce"],
          tx_hash:          result["tx_hash"],
          bump_nonce:       result["bumpNonce"],
          allowance:        result["allowance"],
          attempted_amount: sell_token_amount,
          min_amount_out:   min_amount_out,
          raw:              result["raw"]
        }
      )

      handle_approval(wallet, result, provider_url)

      puts "========================================================"
      puts "TradeExecutionService::sell - Swap failed"
      puts "bot: #{bot.id}, token: #{bot.token_pair.base_token.symbol}, sell_token_amount: #{sell_token_amount.to_s} min_amount_out: #{min_amount_out.to_s}"
      puts "ERROR: #{result}"
      puts "========================================================"
    end

    trade
  end

  private

  def self.build_metrics(vars)
    {
      strategy: vars[:bot].strategy.nft_token_id,
      step: vars[:step],
      cpr: vars[:cpr],
      ppr: vars[:ppr],
      rhi: vars[:rhi],
      ibp: vars[:ibp],
      lbp: vars[:lbp],
      bep: vars[:bep],
      bcn: vars[:bcn],    
      scn: vars[:scn],
      bta: vars[:bta],
      mam: vars[:mam],
      ndp: vars[:ndp],
      nd2: vars[:nd2],
      pdi: vars[:pdi],
      mom: vars[:mom],
      vst: vars[:vst],
      vlt: vars[:vlt],
      ssd: vars[:ssd],
      lsd: vars[:lsd],
      hps: vars[:hps],
      lps: vars[:lps],
      hip: vars[:hip],
      hlt: vars[:hlt],
      lip: vars[:lip],
      llt: vars[:llt],
      cma: vars[:cma],
      lma: vars[:lma],
      pcm: vars[:pcm],
      plm: vars[:plm],
      tma: vars[:tma],
      lmc: vars[:lmc],
      hma: vars[:hma],
      lmi: vars[:lmi],
      hmt: vars[:hmt],
      lmt: vars[:lmt],
      lsp: vars[:lsp],
    }
  end

  def self.handle_approval(wallet, result, provider_url)
    if result["stage"] == "allowance" && result["code"] == "ALLOWANCE_REQUIRED" && result["allowance"]["needsApproval"]
      ApprovalManager.ensure_infinite!(
        wallet:       wallet,
        token:        result["allowance"]["token"],
        provider_url: provider_url
      )
    end
  end
end
