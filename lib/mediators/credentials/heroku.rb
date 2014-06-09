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
      encrypted_token = Fernet.generate(Config.fernet_secret, JSON.generate(message))
      key = "heroku_#{@uid}"
      $redis.set(key, encrypted_token)
      $redis.expire(key, 86400) # a day
    end
  end
end
