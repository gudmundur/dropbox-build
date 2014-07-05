module Mediators::Credentials
  class Dropbox < Mediators::Base
    def initialize(options={})
      @user_id = options[:user_id]
      @dropbox_uid = options[:dropbox_uid]
      @token = options[:token]
    end

    def call
      encrypted_token = Fernet.generate(Config.fernet_secret, @token)
      key = "dropbox_#{@dropbox_uid}"
      heroku_key = "heroku_#{@user_id}"
      $redis.hset(key, 'token', encrypted_token)
      $redis.hset(key, 'user_id', @user_id)
      $redis.hset(heroku_key, 'dropbox_uid', @dropbox_uid)
      $redis.expire(key, 86400) # a day
    end
  end
end
