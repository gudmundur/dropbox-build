module Endpoints
  class Root < Base
    get "/" do
      puts request.env
#      client = Heroku.connect_oauth(request.env['bouncer.token'])
      "hello."
    end
  end
end
