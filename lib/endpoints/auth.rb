require 'pry'

module Endpoints
  class Auth < Base
    get '/auth/:name/callback' do
      auth = request.env['omniauth.auth']

      case auth.provider
      when 'dropbox_oauth2'
        Mediators::Credentials::Dropbox.run(auth)
      when 'heroku'
        Mediators::Credentials::Heroku.run(auth)
      end

      redirect '/'
    end
  end
end
