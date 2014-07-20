require 'dropbox_sdk'

module Endpoints
  class Auth < Base
    get '/auth/:name/callback' do
      auth = request.env['omniauth.auth']

      case auth.provider
      when 'dropbox_oauth2'
        Mediators::Credentials::Dropbox.run({
          user_id: session[:user_id],
          dropbox_uid: auth['uid'],
          dropbox_name: auth.info['name'],
          token: auth['credentials']['token'],
        })
      when 'heroku'
        Mediators::Credentials::Heroku.run(
          user_id: auth.uid,
          token: auth['credentials']['token'],
          refresh_token: auth['credentials']['refresh_token']
        )

        session[:user_id] = auth.uid
      end

      redirect '/'
    end
  end
end
