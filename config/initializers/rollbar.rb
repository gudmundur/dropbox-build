if ENV.key?('ROLLBAR_ACCESS_TOKEN')
  Rollbar.configure do |config|
    config.access_token = ENV.fetch('ROLLBAR_ACCESS_TOKEN')
    config.environment = Sinatra::Base.environment
    config.framework = "Sinatra: #{Sinatra::VERSION}"
  end
end
