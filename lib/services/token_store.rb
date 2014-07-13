module Services
  module TokenStore
    extend self

    def decrypt(encrypted_token)
      verifier = Fernet.verifier(Config.fernet_secret, encrypted_token)
      verifier.message
    end
  end
end

