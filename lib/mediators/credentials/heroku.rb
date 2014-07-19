require 'pry'

module Mediators::Credentials
  class Heroku < Mediators::Base
    def initialize(args)
      @uid = args['uid']
      @token = args['credentials']['token']
      @refresh_token = args['credentials']['refresh_token']
    end

    def call
      message = {
        token:          @token,
        refresh_token:  @refresh_token,
      }
      encrypted_tokens = Fernet.generate(Config.fernet_secret, JSON.generate(message))
      key = "heroku_#{@uid}"

      heroku = Services::Heroku.connect_oauth(@token)
      email = heroku.account.info["email"]

      $redis.hset(key, 'tokens', encrypted_tokens)
      $redis.hset(key, 'email', email)
      $redis.expire(key, Config.token_expiration) # a day
    end
  end
end
