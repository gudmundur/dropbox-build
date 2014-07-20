module Workers
  class HerokuBuilder
    include Sidekiq::Worker

    def perform(user_id, url, version, options={})
      @user_id = user_id
      @url = url
      @version = version
      @request_id = options['request_id']

      begin
        setup_clients
        fetch_app
        submit_build
      rescue Errors::AuthenticationMissing
        log(auth_missing: true)
      rescue Errors::AppMissing
        log(app_missing: true)
      end
    end

    def setup_clients
      @heroku = Services::Heroku.connect_redis(@user_id)
    end

    def fetch_app
      @app_name = $redis.hget(heroku_key, 'app_name')
      raise Errors::AppMissing unless @app_name
    end

    def submit_build(on_retry=false)
      log(submit_build: true) do
        payload = {
          source_blob: {
            url: @url,
            version: @version,
          }
        }

        begin
          @heroku.build.create(@app_name, payload)
        rescue Excon::Errors::Unauthorized => e
          raise e if on_retry

          Mediators::Credentials::HerokuRefresh.run(@user_id)
          submit_build(true)
        end
      end
    end

    private

    def heroku_key
      "heroku_#{@user_id}"
    end

    def log(data={}, &blk)
      Pliny.log({ heroku_builder: true, user: @user_id, request_id: @request_id, app_name: @app_name }.merge(data), &blk)
    end
  end
end
