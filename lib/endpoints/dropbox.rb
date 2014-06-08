require 'openssl'
require 'sidekiq'

module Endpoints
  class Dropbox < Base
    get '/dropbox/hook' do
      puts params[:challenge]
      params[:challenge]
    end

    post '/dropbox/hook' do
      body = request.body.read
      signature = request.env['HTTP_X_DROPBOX_SIGNATURE']

      if signature != hmac_sha256(body)
        return 403
      end

      DropboxDownloader.perform_async(JSON.parse(body))
    end

    private

    def hmac_sha256(body)
      OpenSSL::HMAC.hexdigest('sha256', Config.dropbox_app_secret, body)
    end
  end
end
