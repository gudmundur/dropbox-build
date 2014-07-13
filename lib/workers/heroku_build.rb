require 'pry'

class HerokuBuilder
  include Sidekiq::Worker

  class AuthenticationMissing < StandardError; end

  def perform(user_id, url, version, options={})
    @user_id = user_id
    @url = url
    @version = version
    @request_id = options['request_id']
    # TODO Use a selected app
    @app_name = 'cryptic-atoll-7822'

    begin
      fetch_token
      setup_clients

      submit_build
    rescue AuthenticationMissing
      log(auth_missing: true)
    end
  end

  def fetch_token
    encrypted_token = $redis.hget("heroku_#{@user_id}", 'tokens')
    raise AuthenticationMissing unless encrypted_token

    message = JSON.parse(decrypt(encrypted_token))
    @token = message['token']
  end

  def setup_clients
    @heroku  = Services::Heroku.connect_oauth(@token)
  end

  def submit_build
    log(submit_build: true) do
      payload = {
        source_blob: {
          url: @url,
          version: @version,
        }
      }

      @heroku.build.create(@app_name, payload)
    end
  end

  private

  def log(data={}, &blk)
    Pliny.log({ heroku_builder: true, user: @user_id, request_id: @request_id }.merge(data), &blk)
  end

  def decrypt(message)
    verifier = Fernet.verifier(Config.fernet_secret, message)
    verifier.message
  end
end
