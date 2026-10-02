# Builds real RS256 tokens and a matching JWKS.
#
# The verifier is the one place where "it rejects a bad token" has to mean
# genuine cryptography, so these specs sign for real with a throwaway key
# rather than stubbing JWT.decode -- a stub would pass just as happily if the
# signature check were deleted.
class ClerkTokenFactory
  def self.key
    @key ||= OpenSSL::PKey::RSA.generate(2048)
  end

  def self.kid
    "test-key-1"
  end

  # Round-tripped through JSON so the fixture has the string keys a real JWKS
  # response arrives with, not the symbols JWT::JWK#export returns.
  def self.jwks(key: self.key, kid: self.kid)
    JSON.parse(JSON.generate({ "keys" => [ JWT::JWK.new(key, kid: kid).export ] }))
  end

  def self.token(subject: "user_abc", exp: 1.hour.from_now, nbf: nil, azp: nil, key: self.key, kid: self.kid)
    claims = { "sub" => subject, "exp" => exp.to_i, "iat" => Time.current.to_i }
    claims["nbf"] = nbf.to_i if nbf
    claims["azp"] = azp if azp

    JWT.encode(claims, key, "RS256", { kid: kid })
  end
end
