# spec/requests/rate_limiting_spec.rb
require "rails_helper"

RSpec.describe "Rate Limiting", type: :request do
  # Requires: gem "rack-attack" + config/initializers/rack_attack.rb
  #
  # config/initializers/rack_attack.rb:
  #   Rack::Attack.throttle("login/ip", limit: 5, period: 10.minutes) do |req|
  #     req.ip if req.path == "/users/sign_in" && req.post?
  #   end

  let(:user) { create(:user, password: "correct_password") }

  before do
    # Rack::Attack uses a cache store — clear between examples
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  end

  describe "POST /users/sign_in" do
    context "with wrong credentials" do
      it "allows the first 5 attempts" do
        5.times do
          post user_session_path, params: {
            user: { email: user.email, password: "wrong" }
          }
          expect(response.status).not_to eq(429)
        end
      end

      it "blocks the 6th attempt from the same IP" do
        6.times do
          post user_session_path,
            params: { user: { email: user.email, password: "wrong" } },
            headers: { "REMOTE_ADDR" => "1.2.3.4" }
        end
        expect(response.status).to eq(429)
      end

      it "allows attempts from different IPs independently" do
        5.times do |i|
          post user_session_path,
            params: { user: { email: user.email, password: "wrong" } },
            headers: { "REMOTE_ADDR" => "1.2.3.#{i}" }
          expect(response.status).not_to eq(429)
        end
      end
    end

    context "with correct credentials" do
      it "succeeds on the first attempt" do
        post user_session_path, params: {
          user: { email: user.email, password: "correct_password" }
        }
        expect(response).to redirect_to(root_path)
      end
    end
  end
end