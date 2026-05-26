# spec/requests/authentication_spec.rb
require "rails_helper"

RSpec.describe "Authentication", type: :request do
  describe "Registration" do
    context "with valid params" do
      let(:valid_params) do
        { user: {
          name: "Ana Lima",
          email: "ana@example.com",
          password: "password123",
          password_confirmation: "password123",
          currency: "BRL"
        } }
      end

      it "creates a new user" do
        expect { post user_registration_path, params: valid_params }
          .to change(User, :count).by(1)
      end

      it "signs the user in after registration" do
        post user_registration_path, params: valid_params
        expect(response).to redirect_to(root_path)
      end

      it "sets email_verified_at to nil on creation" do
        post user_registration_path, params: valid_params
        expect(User.last.email_verified_at).to be_nil
      end
    end

    context "with missing name" do
      it "does not create user and shows error" do
        expect {
          post user_registration_path, params: {
            user: { name: "", email: "x@example.com", password: "password123",
                    password_confirmation: "password123" }
          }
        }.not_to change(User, :count)
      end
    end

    context "with duplicate email" do
      let!(:existing) { create(:user, email: "dup@example.com") }

      it "rejects registration" do
        expect {
          post user_registration_path, params: {
            user: { name: "Other", email: "dup@example.com",
                    password: "password123", password_confirmation: "password123" }
          }
        }.not_to change(User, :count)
      end
    end
  end

  describe "Login" do
    let!(:user) { create(:user, password: "mypassword") }

    it "signs in with correct credentials" do
      post user_session_path, params: {
        user: { email: user.email, password: "mypassword" }
      }
      expect(response).to redirect_to(root_path)
    end

    it "rejects wrong password" do
      post user_session_path, params: {
        user: { email: user.email, password: "wrong" }
      }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects unknown email" do
      post user_session_path, params: {
        user: { email: "nobody@example.com", password: "anything" }
      }
      expect(response).not_to redirect_to(root_path)
    end
  end

  describe "Logout" do
    let!(:user) { create(:user) }

    it "signs out the user" do
      sign_in user
      delete destroy_user_session_path
      expect(response).to redirect_to(root_path)
    end
  end

  describe "Password reset" do
    let!(:user) { create(:user, email: "reset@example.com") }

    it "sends reset password instructions" do
      expect {
        post user_password_path, params: { user: { email: user.email } }
      }.to have_enqueued_mail
    end

    it "returns the same observable response for unknown email" do
      post user_password_path, params: { user: { email: user.email } }
      existing_response = [ response.status, response.location, response.body ]

      post user_password_path, params: { user: { email: "ghost@example.com" } }
      unknown_response = [ response.status, response.location, response.body ]

      expect(unknown_response).to eq(existing_response)
    end

    it "does not send reset instructions for unknown email" do
      expect {
        post user_password_path, params: { user: { email: "ghost@example.com" } }
      }.not_to have_enqueued_mail
    end
  end

  describe "Protected routes" do
    it "redirects unauthenticated user to login" do
      get accounts_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
