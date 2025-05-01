# config/initializers/redlock.rb
require "redlock"

# Use your existing $redis connection
REDLOCK_CLIENT = Redlock::Client.new([ $redis ])
