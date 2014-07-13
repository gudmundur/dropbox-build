module Endpoints
  class Root < Base
    set :static, true

    get "/" do
      send_file 'public/index.html'
    end

    get '/app.js' do
      send_file 'public/app.js'
    end
  end
end
