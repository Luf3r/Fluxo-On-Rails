require "rails_helper"

RSpec.describe "Devise pages", type: :request do
  def sign_up_params(overrides = {})
    {
      user: {
        name: "Ana Fluxo",
        email: "ana@example.com",
        password: "password123",
        password_confirmation: "password123",
        currency: "USD"
      }.merge(overrides)
    }
  end

  def auth_response_signature
    {
      status: response.status,
      location: response.location,
      alert: flash[:alert],
      notice: flash[:notice]
    }
  end

  it "loads the sign in page" do
    get new_user_session_path

    expect(response).to have_http_status(:ok)
  end

  it "loads the registration page" do
    get new_user_registration_path

    expect(response).to have_http_status(:ok)
  end

  it "signs up with name, email, password, and currency" do
    post user_registration_path, params: sign_up_params

    expect(response).to redirect_to(root_path)
    expect(User.last).to have_attributes(
      name: "Ana Fluxo",
      email: "ana@example.com",
      currency: "USD"
    )
  end

  it "rejects duplicate email registration" do
    create(:user, email: "ana@example.com")

    expect {
      post user_registration_path, params: sign_up_params
    }.not_to change(User, :count)
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "rejects password confirmation mismatch" do
    expect {
      post user_registration_path, params: sign_up_params(password_confirmation: "different123")
    }.not_to change(User, :count)
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "rejects passwords shorter than the Devise minimum" do
    expect {
      post user_registration_path, params: sign_up_params(password: "short", password_confirmation: "short")
    }.not_to change(User, :count)
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "rejects unsupported currency during registration" do
    expect {
      post user_registration_path, params: sign_up_params(currency: "XYZ")
    }.not_to change(User, :count)
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "does not allow sign up params to set sensitive fields" do
    verified_at = 1.day.ago

    post user_registration_path,
      params: sign_up_params(
        avatar_url: "https://attacker.example/avatar.png",
        email_verified_at: verified_at,
        encrypted_password: "attacker-controlled",
        reset_password_token: "attacker-token"
      )

    user = User.find_by!(email: "ana@example.com")
    expect(user.avatar_url).to be_nil
    expect(user.email_verified_at).to be_nil
    expect(user.encrypted_password).not_to eq("attacker-controlled")
    expect(user.reset_password_token).to be_nil
  end

  it "returns the same observable response for wrong password and unknown email" do
    user = create(:user, email: "known@example.com", password: "password123")

    post user_session_path, params: {
      user: { email: user.email, password: "wrong-password" }
    }
    wrong_password_response = auth_response_signature

    post user_session_path, params: {
      user: { email: "missing@example.com", password: "wrong-password" }
    }
    unknown_email_response = auth_response_signature

    expect(unknown_email_response).to eq(wrong_password_response)
  end

  it "signs out an authenticated user" do
    user = create(:user, password: "password123")
    post user_session_path, params: {
      user: { email: user.email, password: "password123" }
    }

    delete destroy_user_session_path

    expect(response).to redirect_to(root_path)
  end

  describe "password reset" do
    before { ActionMailer::Base.deliveries.clear }

    it "sends reset instructions for an existing email" do
      user = create(:user, email: "reset@example.com")

      expect {
        post user_password_path, params: { user: { email: user.email } }
      }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    it "returns the same observable response for unknown email" do
      user = create(:user, email: "reset@example.com")

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
end
