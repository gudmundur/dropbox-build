Routes = Rack::Builder.new do
  use Pliny::Middleware::RescueErrors unless Config.rack_env == "development"
  use Honeybadger::Rack
  use Pliny::Middleware::CORS
  use Pliny::Middleware::RequestID
  use Pliny::Middleware::RequestStore, store: Pliny::RequestStore
  use Pliny::Middleware::Timeout, timeout: 45
  use Rack::Deflater
  use Rack::MethodOverride
  use Rack::SSL if Config.rack_env == "production"

  use Pliny::Router do
    # mount all endpoints here
    mount Endpoints::Auth
    mount Endpoints::Dropbox
  end

  # root app; but will also handle some defaults like 404
  run Endpoints::Root
end
