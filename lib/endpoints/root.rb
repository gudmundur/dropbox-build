module Endpoints
  class Root < Base
    helpers do
      def heroku?
        session[:user_id]
      end

      def heroku_email
        user_get('email')
      end

      def dropbox?
        !user_get('dropbox_uid').nil?
      end

      def dropbox_name
        user_get('dropbox_name')
      end

      def heroku_apps
        heroku = Services::Heroku.connect_redis(session[:user_id])
        heroku.app.list.map do |app|
          {
            id: app['id'],
            name: app['name']
          }
        end
      end

      private

      def user_get(key)
        $redis.hget(heroku_key, key)
      end

      def heroku_key
        "heroku_#{session[:user_id]}"
      end
    end

    set :static, true

    get "/" do
      erb :index
    end

    get '/app.js' do
      send_file 'public/app.js'
    end
  end
end
