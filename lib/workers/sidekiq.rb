require 'dropbox_sdk'

class DropboxDownloader
  include Sidekiq::Worker

  def perform(payload)
    Pliny.log(hello: 'world')
    puts 'hi'
    puts DropboxClient
  end
end
