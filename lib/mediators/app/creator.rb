module Mediators::App
  class Creator < Mediators::Base
    def initialize(args)
      @user_id = args[:user_id]
    end

    def call
      app = heroku.app.create({})

      $redis.hset(heroku_key, 'app_id', app['id'])
      $redis.hset(heroku_key, 'app_name', app['name'])
      $redis.hset(heroku_key, 'app_url', app['web_url'])
    end

    private

    def heroku_key
      "heroku_#{@user_id}"
    end

    def heroku
      Services::Heroku.connect_redis(@user_id)
    end
  end
end
