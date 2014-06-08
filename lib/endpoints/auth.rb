require 'pry'

module Endpoints
  class Auth < Base
    get '/auth/:name/callback' do
      auth = request.env['omniauth.auth']
#      puts auth.inspect
      binding.pry
    end
  end
end
