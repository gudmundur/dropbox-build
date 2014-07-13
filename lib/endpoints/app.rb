module Endpoints
  class App < Base
    get '/app' do
      content_type :json, charset: 'utf-8'
      apps = heroku.app.list
      apps.map { |app| format_app(app) }.to_json 
    end

    private

    def heroku
      Services::Heroku.connect_redis(session[:user_id])
    end

    def format_app(app)
      {
        id:   app['id'],
        name: app['name'],
      }
    end
  end
end
