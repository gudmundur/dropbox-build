module Endpoints
  class Root < Base
    set :static, true

    get "/" do
      erb :index
    end

    get '/app.js' do
      send_file 'public/app.js'
    end
  end
end
