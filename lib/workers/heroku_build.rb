require 'pry'

class HerokuBuilder
  include Sidekiq::Worker

  def perform(user_id, dropbox_cursor, options={})
    @user_id = user_id
    @cursor = dropbox_cursor
    @app_name = 'cryptic-atoll-7822'

    fetch_token
    setup_clients

    source_url
    submit_build
  end

  def fetch_token
    encrypted_token = $redis.get("heroku_f644eb9c-f2c5-4df8-a1fb-b902697322a4")
    raw_token = JSON.parse(decrypt(encrypted_token))
    @token = raw_token['token']
  end

  def setup_clients

    @heroku  = Services::Heroku.connect_oauth(@token)
    @s3      = AWS::S3.new
    @bucket  = @s3.buckets[Config.s3_bucket_name]
  end

  def source_url
    log(source_url: true) do
      @url = @bucket.objects[cache_name].url_for(:read)
      log(source_url: true, url: @url)
    end
  end

  def submit_build
    log(submit_build: true) do
      payload = {
        source_blob: {
          url: @url
        }
      }

      @heroku.build.create(@app_name, payload)
    end
  end

  private

  def log(data={}, &blk)
    Pliny.log({ heroku_builder: true, user: @user_id }.merge(data), &blk)
  end

  def cache_name
    "#{@user_id}.tar.gz"
  end

  def decrypt(message)
    verifier = Fernet.verifier(Config.fernet_secret, message)
    verifier.message
  end
end
