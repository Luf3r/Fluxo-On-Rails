require "rails_helper"

RSpec.describe "Rate limiting", type: :request do
  let(:user) { create(:user, email: "target@example.com", password: "password123") }

  before do
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.cache.store.clear
  end

  describe "POST /users/sign_in" do
    it "blocks the sixth failed login attempt from the same IP" do
      6.times do
        post user_session_path,
          params: { user: { email: user.email, password: "wrong-password" } },
          headers: { "REMOTE_ADDR" => "1.2.3.4" }
      end

      expect(response).to have_http_status(:too_many_requests)
      expect(response.headers["Retry-After"]).to be_present
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
