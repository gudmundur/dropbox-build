require 'dropbox_sdk'

class DropboxClient
  def self.connect_redis(user_id)
    dropbox_uid = $redis.hget("heroku_#{user_id}", 'dropbox_uid')
    raise Errors::AuthenticationMissing unless dropbox_uid
    encrypted_token = $redis.hget("dropbox_#{dropbox_uid}", 'token')
    raise Errors::AuthenticationMissing unless encrypted_token
    token = Services::TokenStore.decrypt(encrypted_token)
    DropboxClient.new(token)
  end
end
