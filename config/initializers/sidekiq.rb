# config/initializers/sidekiq.rb
Sidekiq.configure_server do |config|
  config.redis = { 
    url: ENV.fetch("REDIS_URL") { "redis://localhost:6379/0" }, 
    ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE }
  }
  
  # Load the schedule from config/sidekiq.yml
  schedule_file = "config/sidekiq.yml"
  if File.exist?(schedule_file) && Sidekiq.server?
    Sidekiq::Scheduler.reload_schedule!
  end
end

Sidekiq.configure_client do |config|
  config.redis = { 
    url: ENV.fetch("REDIS_URL") { "redis://localhost:6379/0" }, 
    ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE }
  }
end
