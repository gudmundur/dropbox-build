require 'openssl'
require 'sidekiq'

module Endpoints
  class Dropbox < Base
    get '/dropbox/hook' do
      params[:challenge]
    end

    post '/dropbox/hook' do
      body = request.body.read
      signature = request.env['HTTP_X_DROPBOX_SIGNATURE']
      request_id = request.env['REQUEST_ID']

      if signature != hmac_sha256(body)
        return 403
      end

      payload = JSON.parse(body)
      users   = payload['delta']['users']

      users.each { |user_id| DropboxDownloader.perform_async(user_id, request_id: request_id) }

      200
    end

    private

    def hmac_sha256(body)
      OpenSSL::HMAC.hexdigest('sha256', Config.dropbox_app_secret, body)
    end
  end
end
