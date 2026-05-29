require "rails_helper"

RSpec.describe "Authentication", type: :request do
  before do
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.cache.store.clear
  end

  def auth_response_signature
    {
      status: response.status,
      location: response.location,
      alert: flash[:alert],
      notice: flash[:notice]
    }
  end

  def sign_up_params(overrides = {})
    {
      user: {
        name: "Ana Lima",
        email: "ana@example.com",
        password: "password123",
        password_confirmation: "password123",
        currency: "BRL"
      }.merge(overrides)
    }
  end

  describe "Registration" do
    context "with valid params" do
      it "creates a new user" do
        expect { post user_registration_path, params: sign_up_params }
          .to change(User, :count).by(1)
      end

      it "signs the user in after registration" do
        post user_registration_path, params: sign_up_params

        expect(response).to redirect_to(root_path)
      end

      it "sends email confirmation instructions" do
        ActionMailer::Base.deliveries.clear

        expect { post user_registration_path, params: sign_up_params }
          .to change { ActionMailer::Base.deliveries.count }.by(1)
      end

      it "greets the user by account name in confirmation instructions" do
        ActionMailer::Base.deliveries.clear

        post user_registration_path, params: sign_up_params(name: "Luiz Silva", email: "luiz@example.com")

        mail_body = ActionMailer::Base.deliveries.last.body.encoded
        expect(mail_body).to include("Welcome, Luiz Silva")
        expect(mail_body).not_to include("Welcome, luiz@example.com")
      end

      it "stores the current locale as the user's preferred email locale" do
        post user_registration_path(locale: :"pt-BR"),
          params: sign_up_params(email: "ana.pt@example.com")

        expect(User.find_by!(email: "ana.pt@example.com").preferred_locale).to eq("pt-BR")
      end

      it "sends confirmation instructions in Portuguese when the registration locale is Portuguese" do
        ActionMailer::Base.deliveries.clear

        post user_registration_path(locale: :"pt-BR"),
          params: sign_up_params(name: "Luiz Silva", email: "luiz.pt@example.com")

        mail = ActionMailer::Base.deliveries.last
        expect(mail.subject).to eq("Instrucoes de confirmacao")
        expect(mail.body.encoded).to include("Bem-vindo, Luiz Silva")
        expect(mail.body.encoded).to include("Confirmar minha conta")
        expect(mail.body.encoded).not_to include("Welcome, Luiz Silva")
      end

      it "sets email_verified_at to nil on creation" do
        post user_registration_path, params: sign_up_params

        expect(User.last.email_verified_at).to be_nil
      end
    end

    context "with missing name" do
      it "does not create user and shows error" do
        expect {
          post user_registration_path,
            params: sign_up_params(name: "")
        }.not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "with duplicate email" do
      before { create(:user, email: "dup@example.com") }

      it "rejects registration" do
        expect {
          post user_registration_path,
            params: sign_up_params(email: "dup@example.com")
        }.not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_content)
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

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns the same observable response for wrong password and unknown email" do
      post user_session_path, params: {
        user: { email: user.email, password: "wrong" }
      }
      wrong_password_response = auth_response_signature

      post user_session_path, params: {
        user: { email: "nobody@example.com", password: "anything" }
      }
      unknown_email_response = auth_response_signature

      expect(unknown_email_response).to eq(wrong_password_response)
    end

    it "rejects SQL injection-shaped login input" do
      post user_session_path, params: {
        user: {
          email: "' OR '1'='1@example.com",
          password: "anything"
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(controller.current_user).to be_nil
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

    before { ActionMailer::Base.deliveries.clear }

    it "sends reset password instructions" do
      expect {
        post user_password_path, params: { user: { email: user.email } }
      }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    it "greets the user by account name in reset password instructions" do
      user.update!(name: "Luiz Silva")

      post user_password_path, params: { user: { email: user.email } }

      mail_body = ActionMailer::Base.deliveries.last.body.encoded
      expect(mail_body).to include("Hello, Luiz Silva")
      expect(mail_body).not_to include("Hello, #{user.email}")
    end

    it "sends reset password instructions in the user's preferred locale" do
      user.update!(name: "Luiz Silva", preferred_locale: "pt-BR")

      post user_password_path, params: { user: { email: user.email } }

      mail = ActionMailer::Base.deliveries.last
      expect(mail.subject).to eq("Instrucoes para redefinir senha")
      expect(mail.body.encoded).to include("Ola, Luiz Silva")
      expect(mail.body.encoded).to include("Alterar minha senha")
      expect(mail.body.encoded).not_to include("Hello, Luiz Silva")
    end

    it "updates the password with a valid reset token" do
      raw_token = user.send_reset_password_instructions

      put user_password_path, params: {
        user: {
          reset_password_token: raw_token,
          password: "new-password123",
          password_confirmation: "new-password123"
        }
      }

      expect(response).to redirect_to(root_path)
      expect(user.reload.valid_password?("new-password123")).to be(true)
    end

    it "returns the same observable response for unknown email" do
      post user_password_path, params: { user: { email: user.email } }
      existing_response = auth_response_signature

      post user_password_path, params: { user: { email: "ghost@example.com" } }
      unknown_response = auth_response_signature

      expect(unknown_response).to eq(existing_response)
    end

    it "does not send reset instructions for unknown email" do
      expect {
        post user_password_path, params: { user: { email: "ghost@example.com" } }
      }.not_to change { ActionMailer::Base.deliveries.count }
    end
  end

  describe "Email confirmation" do
    let(:user) { create(:user, confirmed_at: nil, email_verified_at: nil) }

    it "loads the confirmation instructions page" do
      get new_user_confirmation_path

      expect(response).to have_http_status(:ok)
    end

    it "confirms the user and stores the parity timestamp" do
      user.send_confirmation_instructions

      get user_confirmation_path, params: { confirmation_token: user.reload.confirmation_token }

      expect(response).to redirect_to(root_path)
      expect(user.reload).to be_confirmed
      expect(user.email_verified_at.to_i).to eq(user.confirmed_at.to_i)
    end
  end

  describe "Account editing" do
    let(:user) { create(:user, password: "password123") }

    it "redirects unauthenticated users to login" do
      get edit_user_registration_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "loads the edit account page for authenticated users" do
      sign_in user

      get edit_user_registration_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Conta").or include("Account")
    end

    it "updates profile fields with the current password" do
      sign_in user

      put user_registration_path, params: {
        user: {
          name: "Ana Atualizada",
          currency: "USD",
          preferred_locale: "pt-BR",
          current_password: "password123"
        }
      }

      expect(response).to redirect_to(root_path)
      expect(user.reload).to have_attributes(name: "Ana Atualizada", currency: "USD", preferred_locale: "pt-BR")
    end

    it "does not allow account update params to set sensitive fields" do
      sign_in user

      put user_registration_path, params: {
        user: {
          name: "Ana Segura",
          currency: "EUR",
          current_password: "password123",
          email_verified_at: 1.day.ago,
          confirmed_at: 1.day.ago,
          encrypted_password: "attacker-controlled"
        }
      }

      expect(user.reload.email_verified_at).to be_nil
      expect(user.encrypted_password).not_to eq("attacker-controlled")
    end
  end
end
