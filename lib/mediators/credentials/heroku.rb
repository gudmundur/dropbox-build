require 'pry'

module Mediators::Credentials
  class Heroku < Mediators::Base
    def initialize(args)
      @token = args['credentials']['token']
      @refresh_token = args['credentials']['refresh_token']
    end

    def call
      heroku = Services::Heroku.connect_oauth(@token)
      account_info = heroku.account.info
      message = {
        token:          @token,
        refresh_token:  @refresh_token,
      }
      encrypted_token = Fernet.generate(Config.fernet_secret, JSON.generate(message))
      key = "heroku_#{account_info['id']}"
      $redis.set(key, encrypted_token)
      $redis.expire(key, 86400) # a day
    end
  end
end
