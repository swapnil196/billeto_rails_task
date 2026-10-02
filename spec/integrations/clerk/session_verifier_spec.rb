require "rails_helper"

RSpec.describe Clerk::SessionVerifier do
  let(:jwks_url) { "https://clerk.test/.well-known/jwks.json" }

  def key_source(document = ClerkTokenFactory.jwks)
    http = StubHttpClient.new(jwks_url => StubHttpClient.json(document))
    Clerk::JwksKeySource.new(jwks_url: jwks_url, http: http)
  end

  subject(:verifier) { described_class.new(key_source: key_source) }

  it "accepts a token Clerk signed" do
    session = verifier.verify(ClerkTokenFactory.token(subject: "user_abc"))

    expect(session.user_id).to eq("user_abc")
    expect(session.expires_at).to be_present
  end

  it "refuses an absent token" do
    expect { verifier.verify(nil) }
      .to raise_error(Clerk::VerificationFailed, /no session token/)
  end

  it "refuses a token signed by somebody else" do
    impostor = OpenSSL::PKey::RSA.generate(2048)
    token = ClerkTokenFactory.token(key: impostor)

    expect { verifier.verify(token) }.to raise_error(Clerk::VerificationFailed)
  end

  it "refuses an expired token" do
    token = ClerkTokenFactory.token(exp: 1.hour.ago)

    expect { verifier.verify(token) }
      .to raise_error(Clerk::VerificationFailed, /expired/i)
  end

  it "refuses a token that is not valid yet" do
    token = ClerkTokenFactory.token(nbf: 1.hour.from_now)

    expect { verifier.verify(token) }.to raise_error(Clerk::VerificationFailed)
  end

  it "refuses a token carrying no subject" do
    token = ClerkTokenFactory.token(subject: "")

    expect { verifier.verify(token) }
      .to raise_error(Clerk::VerificationFailed, /no subject/)
  end

  it "refuses something that is not a token at all" do
    expect { verifier.verify("neither.a.jwt") }
      .to raise_error(Clerk::VerificationFailed)
  end

  describe "authorized parties" do
    subject(:verifier) do
      described_class.new(key_source: key_source, authorized_parties: [ "https://ours.example" ])
    end

    it "accepts a token issued for us" do
      token = ClerkTokenFactory.token(azp: "https://ours.example")

      expect(verifier.verify(token).user_id).to eq("user_abc")
    end

    it "refuses a token issued for another origin" do
      token = ClerkTokenFactory.token(azp: "https://attacker.example")

      expect { verifier.verify(token) }
        .to raise_error(Clerk::VerificationFailed, /another party/)
    end

    it "refuses a token with no azp claim when parties are configured" do
      expect { verifier.verify(ClerkTokenFactory.token) }
        .to raise_error(Clerk::VerificationFailed, /another party/)
    end
  end
end
