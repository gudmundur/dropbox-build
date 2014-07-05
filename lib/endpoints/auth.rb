require 'pry'

module Endpoints
  class Auth < Base
    get '/auth/:name/callback' do
      auth = request.env['omniauth.auth']

      case auth.provider
      when 'dropbox_oauth2'
        Mediators::Credentials::Dropbox.run({
          user_id: session[:user_id],
          dropbox_uid: auth['uid'],
          token: auth['credentials']['token'],
        })
      when 'heroku'
        session[:user_id] = auth.uid
        Mediators::Credentials::Heroku.run(auth)
      end

      redirect '/'
    end
  end
end
