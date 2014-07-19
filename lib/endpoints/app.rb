
module Endpoints
  class App < Base
    post '/app' do
      if session[:user_id]
        Mediators::App::Creator.run({
          user_id: session[:user_id],
        })
      end

      redirect '/'
    end
  end
end
