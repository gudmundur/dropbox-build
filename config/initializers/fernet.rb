Fernet::Configuration.run do |config|
  config.enforce_ttl = true
  config.ttl         = 86400 # a day
end
