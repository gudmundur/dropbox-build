module Endpoints
  # The base class for all Sinatra-based endpoints. Use sparingly.
  class Base < Sinatra::Base
    register Pliny::Extensions::Instruments
    register Sinatra::Namespace

    use Rack::Session::Cookie, :key => 'rack.session',
      :secret => Config.session_secret

    use OmniAuth::Builder do
      provider :dropbox_oauth2, Config.dropbox_app_key, Config.dropbox_app_secret
      provider :heroku, Config.heroku_oauth_id, Config.heroku_oauth_secret
    end

    configure :development do
      register Sinatra::Reloader
    end

    not_found do
      content_type :json
      status 404
      "{}"
    end
  end
end
