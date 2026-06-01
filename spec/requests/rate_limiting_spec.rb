require "rails_helper"

RSpec.describe "Rate limiting", type: :request do
  let(:user) { create(:user, email: "target@example.com", password: "password123") }

  before do
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.cache.store.clear
  end

  describe "POST /users/sign_in" do
    it "allows the first five failed attempts" do
      5.times do
        post user_session_path,
          params: { user: { email: user.email, password: "wrong-password" } },
          headers: { "REMOTE_ADDR" => "1.2.3.4" }

        expect(response).not_to have_http_status(:too_many_requests)
      end
    end

    it "blocks the sixth failed login attempt from the same IP" do
      6.times do
        post user_session_path,
          params: { user: { email: user.email, password: "wrong-password" } },
          headers: { "REMOTE_ADDR" => "1.2.3.4" }
      end

      expect(response).to have_http_status(:too_many_requests)
      expect(response.headers["Retry-After"]).to be_present
    end

    it "succeeds with correct credentials on the first attempt" do
      post user_session_path, params: {
        user: { email: user.email, password: "password123" }
      }

      expect(response).to redirect_to(root_path)
    end

    it "allows valid credentials from a different IP before the email limit is reached" do
      5.times do
        post user_session_path,
          params: { user: { email: user.email, password: "wrong-password" } },
          headers: { "REMOTE_ADDR" => "1.2.3.4" }
      end

      post user_session_path,
        params: { user: { email: user.email, password: "password123" } },
        headers: { "REMOTE_ADDR" => "5.6.7.8" }

      expect(response).to redirect_to(root_path)
    end

    it "allows login attempts from different IPs independently" do
      5.times do |i|
        post user_session_path,
          params: { user: { email: user.email, password: "wrong-password" } },
          headers: { "REMOTE_ADDR" => "1.2.3.#{i}" }

        expect(response).not_to have_http_status(:too_many_requests)
      end
    end

    it "blocks repeated attempts against the same normalized email across IPs" do
      11.times do |i|
        post user_session_path,
          params: { user: { email: "  #{user.email.upcase}  ", password: "wrong-password" } },
          headers: { "REMOTE_ADDR" => "10.0.0.#{i}" }
      end

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe "POST /users/password" do
    it "blocks the sixth reset attempt from the same IP" do
      6.times do
        post user_password_path,
          params: { user: { email: user.email } },
          headers: { "REMOTE_ADDR" => "2.3.4.5" }
      end

      expect(response).to have_http_status(:too_many_requests)
    end

    it "blocks repeated reset attempts against the same normalized email across IPs" do
      6.times do |i|
        post user_password_path,
          params: { user: { email: "  #{user.email.upcase}  " } },
          headers: { "REMOTE_ADDR" => "20.0.0.#{i}" }
      end

      expect(response).to have_http_status(:too_many_requests)
    end
  end
end
