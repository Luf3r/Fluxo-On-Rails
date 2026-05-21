require "rails_helper"

RSpec.describe "Devise pages", type: :request do
  it "loads the sign in page" do
    get new_user_session_path

    expect(response).to have_http_status(:ok)
  end

  it "loads the registration page" do
    get new_user_registration_path

    expect(response).to have_http_status(:ok)
  end

  it "signs up with name, email, password, and currency" do
    post user_registration_path, params: {
      user: {
        name: "Ana Fluxo",
        email: "ana@example.com",
        password: "password123",
        password_confirmation: "password123",
        currency: "USD"
      }
    }

    expect(response).to redirect_to(root_path)
    expect(User.last).to have_attributes(
      name: "Ana Fluxo",
      email: "ana@example.com",
      currency: "USD"
    )
  end
end
