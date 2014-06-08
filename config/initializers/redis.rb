require 'uri'
redis_url = URI.parse(Config.redis_url)
$redis = Redis.new(host: redis_url.host,
                   port: redis_url.port,
                   password: redis_url.password
                  )
