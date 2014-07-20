source "https://rubygems.org"
ruby "2.1.2"

gem 'aws-sdk'
gem 'dropbox-sdk'
gem 'fernet'
gem 'heroics'
gem 'oauth2'
gem 'omniauth-dropbox-oauth2'
gem 'omniauth-heroku', git: 'https://github.com/cloudcity/omniauth-heroku.git', branch: 'report_uid_and_extra_params'
gem 'redis'
gem 'representable'
gem 'sidekiq'

gem "multi_json"
gem "oj"
gem "pg"
gem "pliny"
gem "puma"
gem "rack-ssl"
gem "rake"
gem "sequel"
gem "sequel_pg", require: "sequel"
gem "sinatra", require: "sinatra/base"
gem "sinatra-contrib", require: ["sinatra/namespace", "sinatra/reloader"]
gem "sinatra-router"

group :development do
  gem "foreman"
  gem "pry-byebug"
end

group :test do
  gem "committee"
  gem "database_cleaner"
  gem "rack-test"
  gem "rr", require: false
  gem "rspec-core"
  gem "rspec-expectations"
end
