module Services
  module Heroku
    def self.connect_redis(user_id)
      encrypted_token = $redis.hget("heroku_#{user_id}", 'tokens')
      raise Errors::AuthenticationMissing unless encrypted_token

      message = JSON.parse(TokenStore.decrypt(encrypted_token))
      token = message['token']
 
      Services::Heroku.connect_oauth(token) 
    end
  end
end
