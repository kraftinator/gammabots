# config/initializers/redlock.rb
require "redlock"

servers = [
  {
    url:       ENV.fetch("REDIS_URL") { "redis://localhost:6379/0" },
    ssl_params:{ verify_mode: OpenSSL::SSL::VERIFY_NONE }
  }
]

REDLOCK_CLIENT = Redlock::Client.new(
  servers,
  retry_count:  10,    # ~1s of retries (10×100ms)
  retry_delay:  200,   # ms between retries
  lock_ttl:     2_000  # 2s lock lifetime
)
