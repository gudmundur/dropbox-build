module Mediators::Credentials
  class Dropbox < Mediators::Base
    def initialize(args)
      @uid = args['uid']
      @token = args['credentials']['token']
    end

    def call
      encrypted_token = Fernet.generate(Config.fernet_secret, @token)
      key = "dropbox_#{@uid}"
      $redis.hset(key, 'token', encrypted_token)
      $redis.expire(key, 86400) # a day
    end
  end
end
