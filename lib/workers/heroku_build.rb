require 'pry'

module Workers
  class HerokuBuilder
    include Sidekiq::Worker

    def perform(user_id, url, version, options={})
      @user_id = user_id
      @url = url
      @version = version
      @request_id = options['request_id']
      # TODO Use a selected app
      @app_name = 'cryptic-atoll-7822'

      begin
        setup_clients
        submit_build
      rescue Errors::AuthenticationMissing
        log(auth_missing: true)
      end
    end

    def setup_clients
      @heroku = Services::Heroku.connect_redis(@user_id)
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
  end
end
