require 'dropbox_sdk'

module Endpoints
  class Account < Base
    get '/account/heroku' do
      content_type :json, charset: 'utf-8'

      begin
        heroku.account.info.to_json
      rescue Errors::AuthenticationMissing
        halt 401
      end
    end

    get '/account/dropbox' do
      content_type :json, charset: 'utf-8'

      begin
        dropbox.account_info.to_json
      rescue Errors::AuthenticationMissing
        halt 401
      end
    end

    private

    def heroku
      Services::Heroku.connect_redis(session[:user_id])
    end

    def dropbox
      DropboxClient.connect_redis(session[:user_id])
    end

  end
end

