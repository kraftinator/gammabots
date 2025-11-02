# app/services/bot_lock.rb
require 'zlib'

module BotLock
  def with_bot_lock(bot_id)
    key = Zlib.crc32("bot:#{bot_id}")
    got_lock = ActiveRecord::Base.connection.select_value("SELECT pg_try_advisory_lock(#{key})")
    return false unless got_lock

    begin
      yield
      true
    ensure
      ActiveRecord::Base.connection.execute("SELECT pg_advisory_unlock(#{key})")
    end
  end
end