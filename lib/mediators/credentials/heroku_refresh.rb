require 'pry'

module Mediators::Credentials
  class HerokuRefresh < Mediators::Base
    def initialize(args)
      @user_id = args[:user_id]
    end

    def call
      binding.pry

      encrypted_tokens = $redis.hget(heroku_key, 'tokens')
      expired_tokens   = JSON.parse(Services::TokenStore.decrypt(encrypted_tokens))
      refresh_token    = expired_tokens['refresh_token']

      tokens = heroku.oauth_token.create(
        client: { 
          secret: Config.heroku_oauth_secret
        },
        grant: {
          type: 'refresh_token'
        },
        refresh_token: {
          token: refresh_token
        }
      )

      Mediators::Credentials::Heroku.run(
        user_id: @user_id,
        token: tokens['access_token']['token'],
        refresh_token: refresh_token
      )
    end

    def heroku
      Services::Heroku.connect_redis(@user_id)
    end

    def heroku_key
      "heroku_#{@user_id}"
    end
  end
end
